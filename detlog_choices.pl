:- module(detlog_choices, [
    member_cp/2,
    normalise_cp/2,
    cp_list/2
]).

%% member_cp(+CP, -Value)
%
% Enumerate values from a choice packet cp(List).
% cp([]) has no members (fails deterministically).
member_cp(cp([H|_T]), H).
member_cp(cp([_H|T]), V) :-
    T \= [],
    member_cp(cp(T), V).

%% normalise_cp(+CP, -NormalCP)
%
% Flatten nested cp/1 packets into a single flat cp/1.
% Example: cp([1, cp([2,3]), 4]) -> cp([1,2,3,4])
normalise_cp(cp(List), cp(Flat)) :-
    normalise_list(List, Flat).

normalise_list([], []).
normalise_list([cp(Inner)|Rest], Flat) :-
    !,
    normalise_list(Inner, FlatInner),
    normalise_list(Rest, FlatRest),
    append(FlatInner, FlatRest, Flat).
normalise_list([H|T], [H|Flat]) :-
    normalise_list(T, Flat).

%% cp_list(+CP, -List)
%
% Extract the list from a normalised choice packet.
% Fixed (non-cp) values are wrapped in a singleton list.
cp_list(cp(List), NormalList) :-
    !,
    normalise_list(List, NormalList).
cp_list(Fixed, [Fixed]).
