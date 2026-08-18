% examples/cuts.pl — Demonstration 4 & 5 & 6
% Cut analysis examples.

% Demonstration 4: first-solution cut
candidate(a).
candidate(b).
candidate(c).

choose(X) :-
    candidate(X),
    !.

% Demonstration 5: committed branch (if_commit pattern)
classify(X, positive) :-
    X > 0,
    !.
classify(_, non_positive).

% Demonstration 6: unsupported cut (meta-call)
dynamic_test(X) :-
    call(test_goal(X)),
    !,
    X = done.
