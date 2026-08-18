%% detlog.pl — Public API for BASIC Detlog
%
% Converts ordinary SWI-Prolog source into an explicit deterministic
% representation using choice packets (cp/1) and splice/2.

:- module(detlog, [
    detlog/2,
    detlog/3,
    detlog_compile/2
]).

:- use_module(detlog_reader,    [read_source/2]).
:- use_module(detlog_transform, [transform_terms/3]).
:- use_module(detlog_loader,    [load_generated/3]).
:- use_module(detlog_report,    [print_trace/2, print_diagnostics/1]).

% Re-export the runtime predicates so users can call them after detlog/2.
:- use_module(detlog_choices,   [member_cp/2, normalise_cp/2, cp_list/2]).
:- use_module(detlog_splice,    [splice/2]).
:- use_module(detlog_cut,       [first/2, once_det/1, guard/1,
                                  decision/2, if_commit/3, loop_exit/1]).

%% detlog(+InputFile, +Goal)
%
% Read source from InputFile, convert supported constructs,
% load the result, and execute Goal.
%
% Example:
%   ?- detlog('examples/example.pl', colour_choices(C)).
detlog(InputFile, Goal) :-
    detlog(InputFile, Goal, []).

%% detlog(+InputFile, +Goal, +Options)
%
% Options:
%   code(true)       — print generated code to stdout
%   code(File)       — save generated code to File
%   trace(true)      — print transformation trace
detlog(InputFile, Goal, Options) :-
    detlog_compile(InputFile, Options),
    call(detlog_generated:Goal).

%% detlog_compile(+InputFile, +Options)
%
% Read, analyse, transform, and load source from InputFile.
% Does not execute a goal.
detlog_compile(InputFile, Options) :-
    read_source(InputFile, Terms),
    transform_terms(Terms, Generated, Diagnostics),
    print_trace(Diagnostics, Options),
    load_generated(Generated, detlog_generated, Options).
