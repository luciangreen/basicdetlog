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
%   code(true)   — print generated code to stdout
%   code(File)   — save generated code to File
load_generated(Terms, ModuleName, Options) :-
    assert_terms(Terms, ModuleName),
    (   memberchk(code(true), Options)
    ->  print_generated_code(Terms)
    ;   memberchk(code(File), Options), File \= true
    ->  save_generated_code(Terms, File)
    ;   true
    ).

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
    ;   Clause = (H :- _),
        functor(H, F, A),
        (   \+ current_predicate(Module:F/A)
        ->  true
        ;   true   % Already declared; assertz will add a clause
        ),
        catch(
            assertz(Module:Clause),
            error(permission_error(modify, static_procedure, _), _),
            true   % Ignore attempts to assert into static predicates
        )
    ).

print_generated_code(Terms) :-
    writeln('--- Generated Detlog Code ---'),
    maplist(print_term_code, Terms),
    writeln('--- End Generated Code ---').

print_term_code(Term) :-
    (   Term = (Head :- Body)
    ->  format("~w :-~n    ~w.~n~n", [Head, Body])
    ;   format("~w.~n~n", [Term])
    ).

save_generated_code(Terms, File) :-
    setup_call_cleanup(
        open(File, write, Stream),
        (   format(Stream, ':- module(detlog_generated, []).~n~n', []),
            maplist(write_term_code(Stream), Terms)
        ),
        close(Stream)
    ).

write_term_code(Stream, Term) :-
    (   Term = (Head :- Body)
    ->  format(Stream, "~w :-~n    ~w.~n~n", [Head, Body])
    ;   format(Stream, "~w.~n~n", [Term])
    ).
