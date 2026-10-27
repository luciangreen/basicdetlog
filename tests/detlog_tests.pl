:- encoding(utf8).

:- module(detlog_tests, []).

:- use_module(library(plunit)).
:- use_module(library(aggregate)).

% Load all Detlog modules
:- use_module('../detlog_choices').
:- use_module('../detlog_splice').
:- use_module('../detlog_cut').
:- use_module('../detlog_analyser').
:- use_module('../detlog_reader').
:- use_module('../detlog_transform').
:- use_module('../detlog_loader').
:- use_module('../detlog').

% Helper: check that a goal produces exactly one solution.
det_goal(Goal) :-
    aggregate_all(count, Goal, Count),
    Count =:= 1.

decision_test_condition(Value) :-
    Value > 0.

% ============================================================
% Stage 1: cp/1 construction
% ============================================================

:- begin_tests(cp_construction).

test(cp_atom) :-
    C = cp([red, blue]),
    C = cp([red, blue]).

test(cp_numbers) :-
    C = cp([1, 2, 3]),
    C = cp([1, 2, 3]).

test(cp_empty) :-
    C = cp([]),
    C = cp([]).

:- end_tests(cp_construction).

% ============================================================
% Stage 1: packet normalisation
% ============================================================

:- begin_tests(packet_normalisation).

test(normalise_flat, [true(R == cp([1,2,3]))]) :-
    normalise_cp(cp([1,2,3]), R).

test(normalise_nested, [true(R == cp([1,2,3,4]))]) :-
    normalise_cp(cp([1, cp([2,3]), 4]), R).

test(normalise_deeply_nested, [true(R == cp([1,2,3,4,5]))]) :-
    normalise_cp(cp([1, cp([2, cp([3,4]), 5])]), R).

test(normalise_empty_nested, [true(R == cp([1,2]))]) :-
    normalise_cp(cp([1, cp([]), 2]), R).

:- end_tests(packet_normalisation).

% ============================================================
% Stage 1: empty packets
% ============================================================

:- begin_tests(empty_packets).

test(empty_cp_no_members, [fail]) :-
    member_cp(cp([]), _).

test(empty_cp_list, [true(L == [])]) :-
    cp_list(cp([]), L).

:- end_tests(empty_packets).

% ============================================================
% Stage 1: member_cp/2
% ============================================================

:- begin_tests(member_cp).

test(member_single, [true(X == a)]) :-
    member_cp(cp([a]), X), !.

test(member_first, [true(X == red)]) :-
    member_cp(cp([red, blue]), X), !.

test(member_all, [true(Xs == [red,blue])]) :-
    findall(X, member_cp(cp([red,blue]), X), Xs).

test(member_three, [true(Xs == [1,2,3])]) :-
    findall(X, member_cp(cp([1,2,3]), X), Xs).

:- end_tests(member_cp).

% ============================================================
% Stage 2: splice/2 — one packet
% ============================================================

:- begin_tests(splice_one_packet).

test(splice_one, [true(Rows == [[a],[b]])]) :-
    splice([cp([a,b])], Rows).

test(splice_one_empty, [true(Rows == [])]) :-
    splice([cp([])], Rows).

test(splice_empty_list, [true(Rows == [[]])]) :-
    splice([], Rows).

:- end_tests(splice_one_packet).

% ============================================================
% Stage 2: splice/2 — two packets
% ============================================================

:- begin_tests(splice_two_packets).

test(splice_two, [true(Rows == [[1,a],[1,b],[2,a],[2,b]])]) :-
    splice([cp([1,2]), cp([a,b])], Rows).

test(splice_two_first_empty, [true(Rows == [])]) :-
    splice([cp([]), cp([a,b])], Rows).

test(splice_two_second_empty, [true(Rows == [])]) :-
    splice([cp([1,2]), cp([])], Rows).

:- end_tests(splice_two_packets).

% ============================================================
% Stage 2: splice/2 — three packets
% ============================================================

:- begin_tests(splice_three_packets).

test(splice_three, [true(Rows == [[1,a,x],[1,a,y],[1,b,x],[1,b,y],
                                   [2,a,x],[2,a,y],[2,b,x],[2,b,y]])]) :-
    splice([cp([1,2]), cp([a,b]), cp([x,y])], Rows).

:- end_tests(splice_three_packets).

% ============================================================
% Stage 2: splice/2 — fixed values
% ============================================================

:- begin_tests(splice_fixed_values).

test(splice_fixed_middle, [true(Rows == [[1,x,a],[1,x,b],[2,x,a],[2,x,b]])]) :-
    splice([cp([1,2]), x, cp([a,b])], Rows).

test(splice_fixed_only, [true(Rows == [[foo,bar]])]) :-
    splice([foo, bar], Rows).

test(splice_fixed_and_cp, [true(Rows == [[a,1],[a,2]])]) :-
    splice([a, cp([1,2])], Rows).

:- end_tests(splice_fixed_values).

% ============================================================
% Stage 2: splice/2 — ordering
% ============================================================

:- begin_tests(splice_ordering).

test(left_to_right_order, [true(Rows == [[1,a],[1,b],[2,a],[2,b]])]) :-
    splice([cp([1,2]), cp([a,b])], Rows).

test(first_element_first, [true(Rows = [[1|_]|_])]) :-
    splice([cp([1,2,3]), cp([a,b])], Rows).

:- end_tests(splice_ordering).

% ============================================================
% Stage 5: first/2
% ============================================================

:- begin_tests(first_choice).

test(first_of_list, [true(X == a)]) :-
    first([a,b,c], X).

test(first_deterministic, [true]) :-
    det_goal(first([a,b,c], _)).

test(first_empty, [fail]) :-
    first([], _).

test(first_singleton, [true(X == z)]) :-
    first([z], X).

:- end_tests(first_choice).

% ============================================================
% Stage 5: guard/1
% ============================================================

:- begin_tests(guard).

test(guard_succeeds, [true]) :-
    guard(1 > 0).

test(guard_fails, [fail]) :-
    guard(0 > 1).

test(guard_deterministic, [true]) :-
    det_goal(guard(1 > 0)).

test(guard_unification, [true(X == 1)]) :-
    guard(X = 1).

:- end_tests(guard).

% ============================================================
% Stage 5: decision/2
% ============================================================

:- begin_tests(decision).

test(decision_first_branch) :-
    X = 15,
    decision([
        branch(X > 10, large),
        branch(X > 0,  positive),
        branch(true,   other)
    ], R),
    R == large.

test(decision_second_branch) :-
    X = 5,
    decision([
        branch(X > 10, large),
        branch(X > 0,  positive),
        branch(true,   other)
    ], R),
    R == positive.

test(decision_default_branch) :-
    X = -1,
    decision([
        branch(X > 10, large),
        branch(X > 0,  positive),
        branch(true,   other)
    ], R),
    R == other.

test(decision_no_branch, [fail]) :-
    decision([branch(fail, x)], _).

test(decision_uses_caller_context) :-
    decision([branch(decision_test_condition(5), positive),
              branch(true, other)], Result),
    Result == positive.

:- end_tests(decision).

% ============================================================
% Stage 5: if_commit/3
% ============================================================

:- begin_tests(if_commit).

test(if_commit_then) :-
    if_commit(1 > 0, R = yes, R = no),
    R == yes.

test(if_commit_else) :-
    if_commit(0 > 1, R = yes, R = no),
    R == no.

test(if_commit_deterministic_then, [true]) :-
    det_goal(if_commit(true, true, true)).

test(if_commit_deterministic_else, [true]) :-
    det_goal(if_commit(fail, true, true)).

:- end_tests(if_commit).

% ============================================================
% Stage 5: once_det/1
% ============================================================

:- begin_tests(once_det).

test(once_det_succeeds, [true]) :-
    once_det(member(_, [a,b,c])).

test(once_det_deterministic, [true]) :-
    det_goal(once_det(member(_, [a,b,c]))).

test(once_det_first, [true(X == a)]) :-
    once_det(member(X, [a,b,c])).

test(once_det_fails, [fail]) :-
    once_det(fail).

:- end_tests(once_det).

% ============================================================
% Stage 3 & 4: multiple-clause conversion (analyser)
% ============================================================

:- begin_tests(multiple_clause_conversion).

test(analyse_simple_facts) :-
    Terms = [colour(red), colour(blue)],
    detlog_analyser:analyse_terms(Terms, Analysis),
    Analysis = [predicate_info(colour, 1, _, Props)],
    memberchk(nondeterministic, Props),
    memberchk(simple_facts, Props),
    memberchk(convertible, Props).

test(analyse_single_fact) :-
    Terms = [colour(red)],
    detlog_analyser:analyse_terms(Terms, Analysis),
    Analysis = [predicate_info(colour, 1, _, Props)],
    memberchk(simple_facts, Props),
    \+ memberchk(nondeterministic, Props).

test(analyse_rule_no_cut) :-
    Terms = [(p(X) :- q(X))],
    detlog_analyser:analyse_terms(Terms, Analysis),
    Analysis = [predicate_info(p, 1, _, Props)],
    memberchk(convertible, Props).

test(analyse_rule_with_cut) :-
    Terms = [(p(X) :- q(X), !)],
    detlog_analyser:analyse_terms(Terms, Analysis),
    Analysis = [predicate_info(p, 1, _, Props)],
    memberchk(has_cut, Props).

:- end_tests(multiple_clause_conversion).

% ============================================================
% Stage 4: generated choice packets from transform
% ============================================================

:- begin_tests(generated_cp).

test(transform_simple_facts) :-
    Terms = [colour(red), colour(blue)],
    detlog_transform:transform_terms(Terms, Generated, _Diag),
    once(member((colour_choices(cp([red,blue])) :- true), Generated)).

test(transform_single_fact) :-
    Terms = [foo(bar)],
    detlog_transform:transform_terms(Terms, Generated, _Diag),
    member(foo(bar), Generated).

test(cp_values_preserved) :-
    Terms = [size(small), size(medium), size(large)],
    detlog_transform:transform_terms(Terms, Generated, _Diag),
    once(member((size_choices(cp([small,medium,large])) :- true), Generated)).

:- end_tests(generated_cp).

% ============================================================
% Stage 5: cut classification & conversion
% ============================================================

:- begin_tests(cut_conversion).

test(first_solution_cut_diagnostic) :-
    Terms = [candidate(a), candidate(b), candidate(c),
             (choose(X) :- candidate(X), !)],
    detlog_transform:transform_terms(Terms, Generated, Diagnostics),
    member(conversion(choose/1, converted, _), Diagnostics),
    member((choose(_) :- once_det(_)), Generated).

test(if_commit_fact_else_clause_converts) :-
    Terms = [
        (classify(X, positive) :- X > 0, !),
        classify(_, non_positive)
    ],
    detlog_transform:transform_terms(Terms, Generated, Diagnostics),
    member(conversion(classify/2, converted, if_commit_pattern), Diagnostics),
    member((classify(_,_) :- if_commit(_,_,_)), Generated).

test(unsupported_cut_fallback) :-
    Terms = [(dynamic_test(X) :- call(_G), !, X = done)],
    detlog_transform:transform_terms(Terms, _Generated, Diagnostics),
    member(conversion(dynamic_test/1, fallback, unsupported_cut), Diagnostics).

test(if_commit_pattern_detected) :-
    Terms = [
        (classify(X, positive) :- X > 0, !),
        (classify(_, non_positive) :- true)
    ],
    detlog_transform:transform_terms(Terms, Generated, Diagnostics),
    member(conversion(classify/2, converted, if_commit_pattern), Diagnostics),
    member((classify(_,_) :- if_commit(_,_,_)), Generated).

:- end_tests(cut_conversion).

% ============================================================
% Stage 7: generated-code loading and execution
% ============================================================

:- begin_tests(generated_loading).

test(load_and_call) :-
    Terms = [(greeting(hello) :- true)],
    detlog_transform:transform_terms(Terms, Generated, _Diag),
    detlog_loader:load_generated(Generated, detlog_test_module_a, []),
    call(detlog_test_module_a:greeting(hello)).

test(load_choices) :-
    Terms = [fruit(apple), fruit(banana), fruit(cherry)],
    detlog_transform:transform_terms(Terms, Generated, _Diag),
    detlog_loader:load_generated(Generated, detlog_fruit_module, []),
    call(detlog_fruit_module:fruit_choices(cp([apple,banana,cherry]))).

test(reload_replaces_previous_clauses) :-
    detlog_loader:load_generated([version(old)], detlog_reload_module, []),
    detlog_loader:load_generated([version(new)], detlog_reload_module, []),
    \+ call(detlog_reload_module:version(old)),
    call(detlog_reload_module:version(new)).

test(reload_preserves_all_current_clauses) :-
    detlog_loader:load_generated([item(first), item(second)], detlog_multi_module, []),
    findall(Value, detlog_multi_module:item(Value), Values),
    Values == [first, second].

:- end_tests(generated_loading).

% ============================================================
% Integration / semantic tests (Demonstrations 1-5)
% ============================================================

:- begin_tests(integration_semantic).

% Demo 1: colour choices
test(demo1_colour_choices) :-
    C = cp([red, blue]),
    findall(V, member_cp(C, V), Detlog),
    Detlog == [red, blue].

% Demo 2: pair splice
test(demo2_pair_splice) :-
    A_choices = cp([1,2]),
    B_choices = cp([x,y]),
    splice([A_choices, B_choices], Rows),
    Rows == [[1,x],[1,y],[2,x],[2,y]].

% Demo 3: deterministic continuation after splice
test(demo3_sum_continuation) :-
    A_choices = cp([1,2]),
    B_choices = cp([10,20]),
    splice([A_choices, B_choices], Pairs),
    maplist([Pair, Row]>>(
        Pair = [A,B],
        C is A + B,
        Row = [A,B,C]
    ), Pairs, Rows),
    Rows == [[1,10,11],[1,20,21],[2,10,12],[2,20,22]].

% Demo 4: first solution
test(demo4_first_solution) :-
    findall(X, member_cp(cp([a,b,c]), X), Candidates),
    first(Candidates, X),
    X == a.

% Demo 5a: committed branch - positive
test(demo5_classify_positive) :-
    X = 5,
    decision([
        branch(X > 0, positive),
        branch(true,  non_positive)
    ], R),
    R == positive.

% Demo 5b: committed branch - non-positive
test(demo5_classify_non_positive) :-
    X = 0,
    decision([
        branch(X > 0, positive),
        branch(true,  non_positive)
    ], R),
    R == non_positive.

:- end_tests(integration_semantic).

% ============================================================
% Determinism tests (inline checks)
% ============================================================

:- begin_tests(determinism_tests).

test(guard_det) :-
    det_goal(guard(true)).

test(first_det) :-
    det_goal(first([a,b,c], _)).

test(once_det_det) :-
    det_goal(once_det(true)).

test(if_commit_then_det) :-
    det_goal(if_commit(true, true, fail)).

test(if_commit_else_det) :-
    det_goal(if_commit(fail, fail, true)).

test(splice_two_det) :-
    det_goal(splice([cp([1,2]), cp([a,b])], _)).

:- end_tests(determinism_tests).

% ============================================================
% Public API and generated source
% ============================================================

:- begin_tests(public_api).

test(detlog_executes_generated_choices) :-
    detlog('examples/colours.pl', colour_choices(Choices)),
    Choices == cp([red, blue]).

test(detlog_compiles_cut_examples) :-
    detlog_compile('examples/cuts.pl', []),
    detlog_compile('examples/cuts.pl', []),
    findall(Value, detlog_generated:choose(Value), Values),
    Values == [a],
    detlog_generated:classify(5, positive),
    \+ detlog_generated:classify(5, non_positive).

test(code_option_writes_loadable_terms) :-
    tmp_file(detlog_code, File),
    setup_call_cleanup(
        true,
        ( detlog_loader:load_generated(
              [(generated_value('needs quoting') :- once_det(true))],
              detlog_code_module,
                                       [code(File)]),
          setup_call_cleanup(
              open(File, read, Stream),
              ( read_term(Stream, ModuleDirective, []),
                read_term(Stream, ImportDirective, []),
                read_term(Stream, GeneratedTerm, [])
              ),
              close(Stream)),
          ModuleDirective = (:- module(detlog_generated, [])),
          ImportDirective = (:- use_module(detlog_cut, Imports)),
          memberchk(once_det/1, Imports),
          GeneratedTerm = (generated_value('needs quoting') :- once_det(true))
        ),
        ( exists_file(File) -> delete_file(File) ; true )).

:- end_tests(public_api).

% ============================================================
% End of tests
% ============================================================
