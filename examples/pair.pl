% examples/pair.pl — Required Demonstration 2 & 3
% Two choicepoints combined with splice.

a(1).
a(2).
b(x).
b(y).
pair(A, B) :-
    a(A),
    b(B).

% Demonstration 3: arithmetic continuation
b_num(10).
b_num(20).
sum(A, B, C) :-
    a(A),
    b_num(B),
    C is A + B.
