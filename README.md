# BASIC Detlog

A SWI-Prolog source converter that identifies simple Prolog choicepoints,
converts their possible values into explicit **choice packets**, combines
multiple packets with deterministic **splice** operations, and replaces a
small set of common **cut** behaviours with explicit deterministic control
predicates.

---

## What is a Prolog Choicepoint?

Ordinary Prolog execution is nondeterministic: when a predicate has
multiple matching clauses, Prolog creates an implicit *choicepoint* and
can backtrack through all matching alternatives.

```prolog
colour(red).
colour(blue).

?- colour(X).
X = red ;
X = blue.
```

The two solutions are produced by hidden backtracking. Detlog makes those
alternatives **explicit data** instead.

---

## Why Turn Alternatives into Data?

| Implicit (ordinary Prolog) | Explicit (Detlog) |
|---|---|
| Hidden choicepoint in engine | `cp([red, blue])` — a plain Prolog term |
| Backtracking drives control flow | `splice/2` drives combination |
| Cuts commit silently | `if_commit/3`, `once_det/1`, etc. |
| Hard to inspect or optimise | Alternatives are inspectable lists |

The essential Detlog transformation is:

```
implicit alternatives
        +
implicit commitment
        ↓
explicit choice packets
        +
explicit deterministic decisions
```

---

## cp/1 — Choice Packets

A choice packet is a plain Prolog term:

```prolog
cp([red, blue])     % represents two alternatives: red, blue
cp([1, 2, 3])       % three alternatives
cp([])              % no alternatives
```

### member_cp/2

Enumerate alternatives from a choice packet:

```prolog
?- member_cp(cp([red, blue]), X).
X = red ;
X = blue.
```

### normalise_cp/2

Flatten nested packets:

```prolog
?- normalise_cp(cp([1, cp([2,3]), 4]), R).
R = cp([1,2,3,4]).
```

---

## splice/2 — Cartesian Combination

`splice(+Choices, -Rows)` computes the Cartesian product of a list of
choices. Each choice is either a `cp/1` packet or a fixed value.

```prolog
?- splice([cp([1,2]), cp([a,b])], Rows).
Rows = [[1,a],[1,b],[2,a],[2,b]].
```

Fixed values pass through unchanged:

```prolog
?- splice([cp([1,2]), x, cp([a,b])], Rows).
Rows = [[1,x,a],[1,x,b],[2,x,a],[2,x,b]].
```

Empty packets short-circuit to no rows:

```prolog
?- splice([cp([]), cp([a,b])], Rows).
Rows = [].
```

### Central Example

```prolog
a(1). a(2).
b(x). b(y).
```

becomes conceptually:

```prolog
A_choices = cp([1,2])
B_choices = cp([x,y])
```

then:

```prolog
?- splice([cp([1,2]), cp([x,y])], Rows).
Rows = [[1,x],[1,y],[2,x],[2,y]].
```

then deterministic processing:

```prolog
process_rows([], []).
process_rows([[A,B]|Rows], [[A,B]|Results]) :-
    process_rows(Rows, Results).
```

---

## Cut Conversion

Detlog classifies and converts simple Prolog cuts:

| Classification | Example | Replacement |
|---|---|---|
| `first_solution` | `p(X) :- q(X), !.` | `once_det/1` |
| `if_commit` | Two-clause if-then-cut-else | `if_commit/3` |
| `unsupported` | Cut after `call/1` | `fallback` |

### once_det/1

```prolog
once_det(:Goal)
```

Execute Goal with explicit first-result semantics. Succeeds at most once.

```prolog
?- once_det(member(X, [a,b,c])).
X = a.
```

### first/2

```prolog
first(+Candidates, -First)
```

Deterministically select the first element. Fails for empty list.

```prolog
?- first([a,b,c], X).
X = a.
```

### guard/1

```prolog
guard(:Condition)
```

Committed condition: succeeds once if Condition succeeds, fails once otherwise.

```prolog
?- X = 5, guard(X > 0).
X = 5.
```

### decision/2

```prolog
decision(+Branches, -Result)
```

Select the first applicable branch. Each branch is `branch(Condition, Result)`.

```prolog
?- X = 5,
   decision([branch(X>10, large),
             branch(X>0,  positive),
             branch(true, other)], R).
R = positive.
```

### if_commit/3

```prolog
if_commit(:Condition, :Then, :Else)
```

Deterministic committed-choice if-then-else.

```prolog
?- if_commit(X > 0, Type = positive, Type = non_positive), X = 5.
X = 5, Type = positive.
```

### loop_exit/1

```prolog
loop_exit(+Reason)
```

Explicit representation of committed loop termination. Throws a
`detlog_loop_exit(Reason)` exception.

---

## Fallback Behaviour

Predicates that Detlog cannot safely convert are marked **fallback**. The
original Prolog clause is preserved unchanged. Detlog never claims a
predicate is deterministically converted when it is not.

Example — unsupported cut (after `call/1`):

```prolog
dynamic_test(X) :-
    call(test_goal(X)),
    !,
    X = done.
```

Diagnostic:

```
conversion(dynamic_test/1, fallback, unsupported_cut)
```

---

## Public API

### detlog/2

```prolog
detlog(+InputFile, +Goal)
```

Read source from InputFile, convert, load, and execute Goal.

```prolog
?- detlog('examples/colours.pl', colour_choices(C)).
C = cp([red, blue]).
```

### detlog/3

```prolog
detlog(+InputFile, +Goal, +Options)
```

Options:
- `code(true)` — print generated code to stdout
- `code('out.pl')` — save generated code to a file
- `trace(true)` — print transformation trace

```prolog
?- detlog('examples/colours.pl', colour_choices(C), [code(true), trace(true)]).
```

### detlog_compile/2

```prolog
detlog_compile(+InputFile, +Options)
```

Read, analyse, transform, and load without executing a goal.

---

## Examples

The `examples/` directory contains:

| File | Demonstrates |
|---|---|
| `colours.pl` | Demo 1: single choice packet |
| `pair.pl` | Demo 2 & 3: two choicepoints + arithmetic continuation |
| `cuts.pl` | Demos 4–6: cut analysis and fallback |

### Running Demo 1

```prolog
?- use_module('detlog.pl').
?- detlog('examples/colours.pl', colour_choices(C)).
C = cp([red, blue]).
```

### Running Demo 2

```prolog
?- use_module('detlog.pl').
?- use_module('detlog_splice.pl').
?- splice([cp([1,2]), cp([x,y])], Rows).
Rows = [[1,x],[1,y],[2,x],[2,y]].
```

### Running Demo 3 (arithmetic continuation)

```prolog
?- use_module('detlog_splice.pl').
?- splice([cp([1,2]), cp([10,20])], Pairs),
   maplist([P,R]>>(P=[A,B], C is A+B, R=[A,B,C]), Pairs, Rows).
Rows = [[1,10,11],[1,20,21],[2,10,12],[2,20,22]].
```

---

## Running the Tests

```bash
swipl -g "load_test_files([]), run_tests, halt" tests/detlog_tests.pl
```

---

## Module Architecture

| Module | Responsibility |
|---|---|
| `detlog.pl` | Public API and pipeline |
| `detlog_reader.pl` | Read source terms |
| `detlog_analyser.pl` | Detect multiple clauses and cuts |
| `detlog_choices.pl` | cp/1, member_cp/2, normalise_cp/2 |
| `detlog_splice.pl` | splice/2 |
| `detlog_cut.pl` | Cut classification and control predicates |
| `detlog_transform.pl` | Produce converted clauses |
| `detlog_loader.pl` | Load generated terms into a named module |
| `detlog_report.pl` | Trace and fallback diagnostics |

---

## Limitations

- **BASIC scope only**: does not implement memoisation, concurrency, loop
  synthesis, formula optimisation, or Starlog syntax.
- **Simple predicates only**: the converter handles finite fact predicates
  and simple rules. Predicates with arithmetic generators or `findall/3`
  are kept as-is (fallback).
- **Cut support is limited**: only `first_solution` and simple `if_commit`
  patterns are converted; all other cuts produce `fallback`.
- **No module analysis**: the converter does not track cross-module
  predicate definitions.
- **Generated code uses assertz**: loaded terms are asserted into a named
  module at runtime; no file-based compilation is performed unless
  `code(File)` is specified.
