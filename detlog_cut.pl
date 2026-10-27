:- module(detlog_cut, [
    first/2,
    once_det/1,
    guard/1,
    decision/2,
    if_commit/3,
    loop_exit/1,
    classify_cut/3
]).

:- meta_predicate
    once_det(0),
    guard(0),
    decision(:, -),
    if_commit(0, 0, 0).

%% first(+Candidates, -First)
%
% Deterministically select the first element of a list.
% Fails for empty list.
first([H|_], H).

%% once_det(:Goal)
%
% Execute Goal with explicit first-result semantics.
% Succeeds at most once.
once_det(Goal) :-
    (   call(Goal)
    ->  true
    ;   fail
    ).

%% guard(:Condition)
%
% Succeeds exactly once if Condition succeeds, otherwise fails once.
% Represents a committed condition rather than backtracking behaviour.
guard(Condition) :-
    (   call(Condition)
    ->  true
    ;   fail
    ).

%% decision(+Branches, -Result)
%
% Select the first applicable branch.
% Each branch has the form branch(Condition, Result).
% Selects the first branch where Condition succeeds.
%
% Example:
%   decision([branch(X>10, large), branch(X>0, positive), branch(true, other)], R).
decision(Branches0, Result) :-
    strip_module(Branches0, Context, Branches),
    decision_branches(Branches, Context, Result).

decision_branches([branch(Cond, Result)|_], Context, Result) :-
    call(Context:Cond),
    !.
decision_branches([_|Rest], Context, Result) :-
    decision_branches(Rest, Context, Result).

%% if_commit(:Condition, :Then, :Else)
%
% Deterministic committed-choice if-then-else.
% If Condition succeeds, execute Then without leaving a choicepoint.
% Otherwise execute Else.
if_commit(Condition, Then, _Else) :-
    call(Condition),
    !,
    call(Then).
if_commit(_Condition, _Then, Else) :-
    call(Else).

%% loop_exit(+Reason)
%
% Explicit representation of a committed loop termination.
% Throws a controlled exception that loop wrappers may catch.
loop_exit(Reason) :-
    throw(detlog_loop_exit(Reason)).

%% classify_cut(+ClauseBody, +PredicateIndicator, -Classification)
%
% Classify a cut occurring in ClauseBody of Predicate/Arity.
% Returns one of:
%   first_solution        - cut after all goals, single clause with cut
%   if_commit             - cut in head of if-then pattern
%   deterministic_select  - predicate has exactly one matching clause
%   unsupported(Reason)   - cut cannot be safely classified
classify_cut(Body, _PI, Classification) :-
    body_cut_classification(Body, Classification).

% A body that is just a cut: first_solution
body_cut_classification('!', first_solution) :- !.

% A terminal cut commits to the first result of the preceding goals.
body_cut_classification((Cond, '!'), first_solution) :-
    \+ contains_meta_call(Cond),
    !.
body_cut_classification((Cond, '!', _), if_commit) :-
    \+ contains_meta_call(Cond),
    !.

% Cut after goals with meta-call: unsupported
body_cut_classification(Body, unsupported(meta_call)) :-
    contains_meta_call(Body),
    contains_cut(Body),
    !.

% Any remaining body with a cut
body_cut_classification(Body, first_solution) :-
    contains_cut(Body),
    !.

body_cut_classification(_, deterministic_select).

contains_cut('!') :- !.
contains_cut((A, _)) :- contains_cut(A), !.
contains_cut((_, B)) :- contains_cut(B), !.
contains_cut((A ; _)) :- contains_cut(A), !.
contains_cut((_ ; B)) :- contains_cut(B), !.
contains_cut((A -> _)) :- contains_cut(A), !.
contains_cut((_ -> B)) :- contains_cut(B), !.

contains_meta_call(call(_)) :- !.
contains_meta_call(call(_, _)) :- !.
contains_meta_call(Goal) :-
    functor(Goal, F, _),
    memberchk(F, [call, apply, maplist, foldl, aggregate, bagof, setof, findall]),
    !.
contains_meta_call((A, _)) :- contains_meta_call(A), !.
contains_meta_call((_, B)) :- contains_meta_call(B), !.
contains_meta_call((A ; _)) :- contains_meta_call(A), !.
contains_meta_call((_ ; B)) :- contains_meta_call(B), !.
contains_meta_call((A -> _)) :- contains_meta_call(A), !.
contains_meta_call((_ -> B)) :- contains_meta_call(B), !.
