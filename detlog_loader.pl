:- module(detlog_loader, [
    load_generated/2,
    load_generated/3
]).

%% load_generated(+Terms, +Module)
%
% Assert generated Prolog terms into a named dynamic module.
load_generated(Terms, detlog_generated) :-
    load_generated(Terms, detlog_generated, []).

%% load_generated(+Terms, +ModuleName, +Options)
%
% Options:
%   code(true)   - print generated code to stdout
%   code(File)   - save generated code to File
load_generated(Terms, ModuleName, Options) :-
    ensure_runtime_imports(Terms, ModuleName),
    clear_generated_predicates(Terms, ModuleName),
    assert_terms(Terms, ModuleName),
    (   memberchk(code(true), Options)
    ->  print_generated_code(Terms)
    ;   memberchk(code(File), Options), File \= true
    ->  save_generated_code(Terms, File)
    ;   true
    ).

ensure_runtime_imports(Terms, ModuleName) :-
    runtime_imports(Terms, Imports),
    (   Imports = []
    ->  true
    ;   use_module(ModuleName:detlog_cut, Imports)
    ).

runtime_imports(Terms, Imports) :-
    findall(PredicateIndicator,
        ( runtime_helper(PredicateIndicator, Pattern),
          sub_term(Pattern, Terms)
        ),
        Imports0),
    sort(Imports0, Imports).

runtime_helper(once_det/1, once_det(_)).
runtime_helper(if_commit/3, if_commit(_, _, _)).

clear_generated_predicates(Terms, ModuleName) :-
    findall(F/A,
        ( member(Term, Terms),
          generated_head(Term, Head),
          functor(Head, F, A)
        ),
        PredicateIndicators0),
    sort(PredicateIndicators0, PredicateIndicators),
    maplist(clear_generated_predicate(ModuleName), PredicateIndicators).

generated_head((Head :- _Body), Head) :-
    callable(Head),
    !.
generated_head(Head, Head) :-
    callable(Head),
    \+ is_list(Head).

clear_generated_predicate(ModuleName, F/A) :-
    functor(Head, F, A),
    retractall(ModuleName:Head).

assert_terms([], _).
assert_terms([Term|Rest], ModuleName) :-
    assert_one_term(Term, ModuleName),
    assert_terms(Rest, ModuleName).

assert_one_term(Term, Module) :-
    (   Term = (Head :- Body)
    ->  Clause = (Head :- Body)
    ;   callable(Term)
    ->  Clause = (Term :- true)
    ;   true, Clause = skip
    ),
    (   Clause = skip
    ->  true
    ;   assertz(Module:Clause)
    ).

print_generated_code(Terms) :-
    writeln('--- Generated Detlog Code ---'),
    maplist(print_term_code, Terms),
    writeln('--- End Generated Code ---').

print_term_code(Term) :-
    write_term(Term, [quoted(true), numbervars(true), fullstop(true), nl(true)]),
    nl.

save_generated_code(Terms, File) :-
    setup_call_cleanup(
        open(File, write, Stream),
        (   format(Stream, ':- module(detlog_generated, []).~n', []),
            write_runtime_imports(Stream, Terms),
            maplist(write_term_code(Stream), Terms)
        ),
        close(Stream)
    ).

write_runtime_imports(Stream, Terms) :-
    runtime_imports(Terms, Imports),
    (   Imports = []
    ->  nl(Stream)
    ;   format(Stream, ':- use_module(detlog_cut, ~q).~n~n', [Imports])
    ).

write_term_code(Stream, Term) :-
    write_term(Stream, Term,
               [quoted(true), numbervars(true), fullstop(true), nl(true)]),
    nl(Stream).
