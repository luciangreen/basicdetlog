:- module(detlog_splice, [
    splice/2
]).

:- use_module(detlog_choices, [cp_list/2]).

%% splice(+Choices, -Rows)
%
% Compute the Cartesian product of a list of choices.
% Each choice is either a cp/1 packet or a fixed value.
% Returns a list of rows, each row being a list of one element
% per input choice.
%
% Example:
%   splice([cp([1,2]), cp([a,b])], Rows)
%   Rows = [[1,a],[1,b],[2,a],[2,b]]
%
% Fixed value example:
%   splice([cp([1,2]), x, cp([a,b])], Rows)
%   Rows = [[1,x,a],[1,x,b],[2,x,a],[2,x,b]]
%
% Empty packet short-circuits to empty result:
%   splice([cp([]), cp([a,b])], Rows)
%   Rows = []

splice(Choices, Rows) :-
    splice_product(Choices, [[]], Rows).

splice_product([], Acc, Acc) :- !.
splice_product([Choice|Rest], Acc, Rows) :-
    cp_list(Choice, Values),
    (   Values = []
    ->  Rows = []
    ;   extend_rows(Acc, Values, NewAcc),
        splice_product(Rest, NewAcc, Rows)
    ).

%% extend_rows(+Rows, +Values, -Extended)
%
% For each existing row and each value, append value to row.
extend_rows([], _, []) :- !.
extend_rows([Row|Rows], Values, Extended) :-
    extend_one_row(Row, Values, RowExtended),
    extend_rows(Rows, Values, RestExtended),
    append(RowExtended, RestExtended, Extended).

extend_one_row(_, [], []) :- !.
extend_one_row(Row, [V|Vs], [NewRow|Rest]) :-
    append(Row, [V], NewRow),
    extend_one_row(Row, Vs, Rest).
