:- module(detlog_transform, [
    transform_terms/3
]).

:- use_module(detlog_analyser, [analyse_terms/2]).
:- use_module(detlog_cut,      [classify_cut/3]).

%% transform_terms(+Terms, -Generated, -Diagnostics)
%
% Main transformation entry point.
% Analyses Terms, converts supported predicates, and returns
% generated Prolog terms plus a list of diagnostics.

transform_terms(Terms, Generated, Diagnostics) :-
    analyse_terms(Terms, Analysis),
    maplist(transform_predicate, Analysis, GeneratedLists, Diagnostics),
    flatten(GeneratedLists, Generated).

%% transform_predicate(+Info, -Generated, -Diagnostic)
transform_predicate(predicate_info(F, A, Clauses, Props), Generated, Diag) :-
    PI = F/A,
    (   memberchk(convertible, Props)
    ->  (   memberchk(simple_facts, Props), memberchk(nondeterministic, Props)
        ->  % Multiple unit facts: generate cp/1 representation + originals
            transform_simple_facts(F, A, Clauses, Generated),
            Diag = conversion(PI, converted, multiple_facts_to_cp)
        ;   memberchk(simple_facts, Props)
        ->  % Single fact: keep as-is
            Generated = Clauses,
            Diag = conversion(PI, converted, single_fact)
        ;   % Rules without cuts: keep + potentially transform
            transform_rules(F, A, Clauses, Generated),
            Diag = conversion(PI, converted, rules_transformed)
        )
    ;   memberchk(fallback(has_cut), Props)
    ->  transform_with_cut(F, A, Clauses, Generated, Diag)
    ;   Generated = Clauses,
        Diag = conversion(PI, fallback, unknown)
    ).

%% transform_simple_facts(+F, +A, +Clauses, -Generated)
%
% For predicates that are pure simple facts with multiple clauses,
% generate:
%   1. A _choices predicate: F_choices(cp([V1,V2,...]))
%   2. The original clauses (retained for backward compatibility)
transform_simple_facts(F, A, Clauses, Generated) :-
    extract_fact_heads(Clauses, Heads),
    atom_concat(F, '_choices', ChoiceF),
    (   A =:= 1
    ->  maplist(arg(1), Heads, Values),
        ChoiceHead =.. [ChoiceF, cp(Values)]
    ;   maplist(head_to_row, Heads, Rows),
        ChoiceHead =.. [ChoiceF, cp(Rows)]
    ),
    ChoiceClause = (ChoiceHead :- true),
    Generated = [ChoiceClause | Clauses].

extract_fact_heads([], []).
extract_fact_heads([Clause|Rest], [Head|Heads]) :-
    (   Clause = (Head :- true)
    ->  true
    ;   Head = Clause
    ),
    extract_fact_heads(Rest, Heads).

head_to_row(Head, Row) :-
    Head =.. [_F|Args],
    Row =.. [row|Args].

%% transform_rules(+F, +A, +Clauses, -Generated)
%
% Transform rule predicates (no cuts): keep as-is for BASIC Detlog.
transform_rules(_F, _A, Clauses, Clauses).

%% transform_with_cut(+F, +A, +Clauses, -Generated, -Diag)
%
% Handle predicates containing cuts.
transform_with_cut(F, A, Clauses, Generated, Diag) :-
    PI = F/A,
    (   Clauses = [SingleClause]
    ->  transform_cut_single(F, A, SingleClause, Generated, CutClass),
        (   CutClass = unsupported(_)
        ->  Diag = conversion(PI, fallback, unsupported_cut)
        ;   Diag = conversion(PI, converted, cut_class(CutClass))
        )
    ;   Clauses = [C1, C2],
        C1 = (_ :- Body1),
        extract_if_commit_parts(Body1, _Cond, _Then)
    ->  transform_two_clause_if_commit(F, A, C1, C2, Generated),
        Diag = conversion(PI, converted, if_commit_pattern)
    ;   Generated = Clauses,
        Diag = conversion(PI, fallback, unsupported_cut)
    ).

%% transform_cut_single(+F, +A, +Clause, -Generated, -Classification)
transform_cut_single(F, A, (Head :- Body), Generated, Classification) :-
    !,
    classify_cut(Body, F/A, Classification),
    (   Classification = first_solution
    ->  remove_cut(Body, BodyNoCut),
        NewBody = once_det(BodyNoCut),
        Generated = [(Head :- NewBody)]
    ;   Classification = if_commit
    ->  extract_if_commit_parts(Body, Cond, Then),
        NewBody = if_commit(Cond, Then, fail),
        Generated = [(Head :- NewBody)]
    ;   % unsupported or other
        Generated = [(Head :- Body)]
    ).
transform_cut_single(_F, _A, Fact, [Fact], deterministic_select).

%% transform_two_clause_if_commit(+F, +A, +C1, +C2, -Generated)
%
% Detect the pattern:
%   p(Args1) :- Cond, !.       (no "then" body after cut, result is in head)
%   p(Args2) :- ElseBody.
% and replace with if_commit/3.
%
% Generates:
%   p(SharedArgs, R) :- if_commit(Cond, R = ThenResult, R = ElseResult).
% for simple single-output predicates.
transform_two_clause_if_commit(F, _A, C1, C2, Generated) :-
    clause_parts(C1, Head1, Body1),
    clause_parts(C2, Head2, Body2),
    extract_if_commit_parts(Body1, Cond, ThenBody),
    Head1 =.. [F | Args1],
    Head2 =.. [F | Args2],
    build_if_commit_clause(F, Args1, Args2, Cond, ThenBody, Body2, NewClause),
    Generated = [NewClause].

clause_parts((Head :- Body), Head, Body) :-
    !.
clause_parts(Head, Head, true).

%% build_if_commit_clause(+F, +Args1, +Args2, +Cond, +ThenBody, +ElseBody, -Clause)
%
% Build a single if_commit clause from two clause patterns.
% For simple cases where heads differ only in one output arg:
%   then goal = ThenBody + head unifications
%   else goal = ElseBody + head unifications
build_if_commit_clause(F, Args1, Args2, Cond, ThenBody, ElseBody, Clause) :-
    length(Args1, Arity),
    length(NewArgs, Arity),
    build_arg_goals(Args1, Args2, NewArgs, ThenGoals, ElseGoals),
    NewHead =.. [F | NewArgs],
    goals_to_goal([ThenBody | ThenGoals], ThenGoal),
    goals_to_goal([ElseBody | ElseGoals], ElseGoal),
    Clause = (NewHead :- if_commit(Cond, ThenGoal, ElseGoal)).

%% build_arg_goals(+Args1, +Args2, +NewArgs, -ThenGoals, -ElseGoals)
%
% For each argument position:
%   - If Args1[i] and Args2[i] are both variables or equal: use same NewArgs[i]
%   - If they differ: NewArgs[i] is fresh, ThenGoals gets NewArg = Args1[i],
%                     ElseGoals gets NewArg = Args2[i]
build_arg_goals([], [], [], [], []).
build_arg_goals([A1|As1], [A2|As2], [NA|NAs], ThenGs, ElseGs) :-
    build_arg_goals(As1, As2, NAs, ThenRest, ElseRest),
    (   var(A1), var(A2)
    ->  NA = A1, A2 = A1,
        ThenGs = ThenRest,
        ElseGs = ElseRest
    ;   var(A1), \+ var(A2)
    ->  NA = A1,
        ThenGs = ThenRest,
        ElseGs = [A1 = A2 | ElseRest]
    ;   \+ var(A1), var(A2)
    ->  NA = A2,
        ThenGs = [A2 = A1 | ThenRest],
        ElseGs = ElseRest
    ;   A1 == A2
    ->  NA = A1,
        ThenGs = ThenRest,
        ElseGs = ElseRest
    ;   % Both ground or different: use fresh NewArg
        ThenGs = [NA = A1 | ThenRest],
        ElseGs = [NA = A2 | ElseRest]
    ).

goals_to_goal(Goals, Goal) :-
    exclude(==(true), Goals, Filtered),
    (   Filtered = []
    ->  Goal = true
    ;   Filtered = [G]
    ->  Goal = G
    ;   Filtered = [G1|Rest],
        foldl([G, Acc, (Acc,G)]>>true, Rest, G1, Goal)
    ).

%% extract_if_commit_parts(+Body, -Cond, -Then)
%
% Match body patterns that represent if-commit (cut-based selection):
%   (Cond, !, Then) -> Cond, Then
%   (Cond, !)       -> Cond, true
extract_if_commit_parts((Cond, !, Then), Cond, Then) :- !.
extract_if_commit_parts((Cond, !),       Cond, true) :- !.

%% remove_cut(+Body, -BodyNoCut)
remove_cut('!', true) :- !.
remove_cut((A, B), Result) :-
    !,
    remove_cut(A, A2),
    remove_cut(B, B2),
    (   A2 = true -> Result = B2
    ;   B2 = true -> Result = A2
    ;   Result = (A2, B2)
    ).
remove_cut(G, G).
