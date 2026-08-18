:- module(detlog_report, [
    print_diagnostics/1,
    print_trace/2,
    format_diagnostic/2
]).

%% print_diagnostics(+Diagnostics)
%
% Print a human-readable summary of conversion diagnostics.
print_diagnostics([]).
print_diagnostics([Diag|Rest]) :-
    format_diagnostic(Diag, Lines),
    maplist(writeln, Lines),
    print_diagnostics(Rest).

%% format_diagnostic(+Diagnostic, -Lines)
format_diagnostic(conversion(PI, converted, Reason), Lines) :-
    !,
    format(atom(L), 'converted: ~w  [~w]', [PI, Reason]),
    Lines = [L].
format_diagnostic(conversion(PI, fallback, Reason), Lines) :-
    !,
    format(atom(L), 'fallback:  ~w  [~w]', [PI, Reason]),
    Lines = [L].
format_diagnostic(Other, [Other]).

%% print_trace(+Diagnostics, +Options)
%
% If trace(true) is in Options, print transformation trace.
print_trace(Diagnostics, Options) :-
    (   memberchk(trace(true), Options)
    ->  writeln('--- Detlog transformation trace ---'),
        print_diagnostics(Diagnostics),
        writeln('--- end trace ---')
    ;   true
    ).
