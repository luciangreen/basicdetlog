:- module(detlog_analyser, [
    analyse_terms/2
]).

%% analyse_terms(+Terms, -Analysis)
%
% Analyse a list of Prolog terms (facts/rules) and return a
% structured analysis suitable for transformation.
%
% Analysis is a list of predicate_info/4 terms:
%   predicate_info(Functor, Arity, Clauses, Properties)
%
% Properties include:
%   nondeterministic   - predicate has multiple clauses
%   has_cut            - at least one clause contains a cut
%   simple_facts       - all clauses are unit clauses (facts)
%   convertible        - can be safely converted to explicit choice
%   fallback(Reason)   - cannot be safely converted

analyse_terms(Terms, Analysis) :-
    group_clauses(Terms, Groups),
    maplist(analyse_predicate, Groups, Analysis).

%% group_clauses(+Terms, -Groups)
%
% Group terms by functor/arity, preserving first-seen order.
group_clauses(Terms, Groups) :-
    group_clauses_acc(Terms, [], RevGroups),
    reverse(RevGroups, Groups).

group_clauses_acc([], Acc, Acc).
group_clauses_acc([Term|Rest], Acc, Groups) :-
    (   clause_pi(Term, PI)
    ->  (   select(group(PI, Clauses), Acc, Remaining)
        ->  append(Clauses, [Term], NewClauses),
            group_clauses_acc(Rest, [group(PI, NewClauses)|Remaining], Groups)
        ;   group_clauses_acc(Rest, [group(PI, [Term])|Acc], Groups)
        )
    ;   % Skip non-clause terms (directives, etc.)
        group_clauses_acc(Rest, Acc, Groups)
    ).

clause_pi((Head :- _Body), F/A) :-
    !,
    functor(Head, F, A).
clause_pi(Head, F/A) :-
    callable(Head),
    \+ is_list(Head),
    Head \= (_ :- _),
    functor(Head, F, A).

%% analyse_predicate(+Group, -Info)
analyse_predicate(group(F/A, Clauses), predicate_info(F, A, Clauses, Properties)) :-
    compute_properties(Clauses, Properties).

%% compute_properties(+Clauses, -Properties)
compute_properties(Clauses, Properties) :-
    length(Clauses, N),
    ( N > 1           -> P_nd  = [nondeterministic] ; P_nd  = [] ),
    ( all_facts(Clauses) -> P_sf  = [simple_facts|P_nd]  ; P_sf  = P_nd  ),
    ( any_has_cut(Clauses) -> P_cut = [has_cut|P_sf]    ; P_cut = P_sf   ),
    determine_convertibility(Clauses, P_cut, Properties).

all_facts([]).
all_facts([Clause|Rest]) :-
    is_fact(Clause),
    all_facts(Rest).

is_fact(Head) :-
    callable(Head),
    \+ is_list(Head),
    Head \= (_ :- _).
is_fact((Head :- true)) :-
    callable(Head).

any_has_cut([Clause|_]) :-
    clause_has_cut(Clause),
    !.
any_has_cut([_|Rest]) :-
    any_has_cut(Rest).

clause_has_cut((_ :- Body)) :-
    body_has_cut(Body).

body_has_cut('!') :- !.
body_has_cut((A, _)) :- body_has_cut(A), !.
body_has_cut((_, B)) :- body_has_cut(B), !.
body_has_cut((A ; _)) :- body_has_cut(A), !.
body_has_cut((_ ; B)) :- body_has_cut(B), !.
body_has_cut((A -> _)) :- body_has_cut(A), !.
body_has_cut((_ -> B)) :- body_has_cut(B), !.

determine_convertibility(Clauses, Props, [convertible|Props]) :-
    \+ memberchk(has_cut, Props),
    all_bodies_safe(Clauses),
    !.
determine_convertibility(_Clauses, Props, [fallback(has_cut)|Props]) :-
    memberchk(has_cut, Props),
    !.
determine_convertibility(_Clauses, Props, [convertible|Props]).

all_bodies_safe([]).
all_bodies_safe([Clause|Rest]) :-
    body_safe(Clause),
    all_bodies_safe(Rest).

body_safe(Head) :- is_fact(Head), !.
body_safe((_ :- Body)) :- \+ body_has_cut(Body).
