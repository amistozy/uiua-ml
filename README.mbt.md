# `amistozy/uiuaml`

UiuaML is a small experimental array language implemented in MoonBit.

It is inspired by [Uiua](https://www.uiua.org/), but it uses an ML-style,
expression-oriented syntax instead of Uiua's stack-based tacit notation. The
project is intentionally compact: the goal is not to reproduce all of Uiua, but
to explore a practical subset of array programming ideas with a real flat array
runtime, first-class functions, and a growing standard library of array
operators.

## Overview

UiuaML currently supports:

- `fill ... in ...` scoped fill values for structural array operations
- `let ... in ...` bindings
- `fun x -> ...` anonymous functions
- function application
- `if ... then ... else ...` expressions
- dynamic values:
  - numbers
  - booleans
  - arrays
  - closures
  - builtins with partial application
- rectangular array literals such as `[1, 2, 3]` and `[[1, 2], [3, 4]]`
- pervasive arithmetic and comparisons
- a flat `shape + data` array representation
- row-oriented higher-order array combinators
- a small CLI for evaluating expressions and files

## Quick Examples

### Basic expressions

```text
let inc = fun x -> x + 1 in inc 41
let add = fun x -> fun y -> x + y in add 3 4
if sum [1, 1, 1] == 3 then 42 else 0
fill 0 in take 6 [1, 2, 3]
```

### Arrays and broadcasting

```text
[1, 2, 3] + 10
[1, 2, 3] + [10, 20, 30]
[10, 20] + [[3, 4, 5], [6, 7, 8]]
```

### Higher-order array programming

```text
map (fun x -> x + 1) [1, 2, 3]
filter (fun x -> x > 2) [1, 2, 3, 4, 5]
zip (fun x -> fun y -> x + y) [1, 2, 3] [10, 20, 30]
reduce (fun acc -> fun x -> acc + x) 0 [1, 2, 3, 4]
scan (fun acc -> fun x -> acc + x) 0 [1, 2, 3, 4]
```

### Array transforms

```text
shape [[1, 2], [3, 4]]
transpose [[1, 2, 3], [4, 5, 6]]
windows 3 [1, 2, 3, 4, 5]
orient [1, 0] [[1, 2, 3], [4, 5, 6]]
orient [-1] [[1, 2, 3], [4, 5, 6]]
fill 0 in orient [0, 0] [1, 2, 3, 4]
select (where [0, 1, 0, 1]) [2, 8, 3, 9]
```

## Current Builtins

### Shape and indexing

- `shape`
- `rank`
- `len`
- `first`
- `last`
- `pick`
- `select`
- `where`

### Structural array operations

- `range`
- `iota`
- `reverse`
- `deshape`
- `reshape`
- `append`
- `take`
- `drop`
- `windows`

### Axis operations

- `transpose`
- `orient`
- `rotate`

### Aggregation, predicates, and higher-order operators

- `sum`
- `any`
- `all`
- `count`
- `keep`
- `map`
- `each`
- `filter`
- `zip`
- `reduce`
- `scan`

## Array Semantics

UiuaML uses a flat array model:

- every array has a shape
- leaf values are stored in row-major order
- arrays must be rectangular

This makes shape-driven operations much easier to define than a nested-list
representation would. It also keeps the runtime model closer to Uiua's array
semantics.

### Broadcasting

Binary arithmetic and comparison operators are pervasive:

- scalars broadcast across arrays
- arrays with the same shape combine element-wise
- arrays can also combine when one shape is a prefix of the other

Examples:

```text
[1, 2, 3] + 10
[1, 2, 3] + [10, 20, 30]
[10, 20] + [[3, 4, 5], [6, 7, 8]]
```

### Row-oriented combinators

Several builtins operate along the leading axis:

- `map` and `each` apply a function to each row
- `filter` keeps rows whose predicate result is truthy
- `zip` combines rows from two arrays
- `reduce` folds rows into a single accumulator
- `scan` returns all intermediate accumulator states

For vectors, the "rows" are just individual elements. For matrices and
higher-rank arrays, the rows are leading-axis slices.

## Syntax Notes

### Comments

Line comments begin with `#`.

```text
let xs = range 4 # build a vector
in sum xs
```

### Negative numbers

Negative values work in normal expressions and builtin calls.

```text
take -2 [1, 2, 3, 4, 5]
drop -2 [1, 2, 3, 4, 5]
rotate -1 [[1, 2], [3, 4], [5, 6]]
```

### Fill scopes

`fill value in expr` installs a temporary fill value for structural operations
inside `expr`.

```text
fill 0 in take 5 [1, 2, 3]
fill [9, 9] in select [0, 9, -1] [[1, 2], [3, 4]]
fill 0 in reshape [2, 3] [1, 2, 3, 4]
```

## CLI

The command line interface lives in `cmd/main` and uses
`moonbitlang/core/argparse`.

### Evaluate an expression

```bash
moon run cmd/main -- eval "sum [1, 2, 3, 4]"
```

### Evaluate a file

```bash
moon run cmd/main -- run program.ua
```

### Show help

```bash
moon run cmd/main -- --help
```

## Library API

The public entry point is:

```mbt nocheck
pub fn interpret(source : StringView) -> String raise UiuaMLError
```

It tokenizes the source, parses it, evaluates it, and renders the final value.

Example:

```mbt nocheck
///|
test "interpret an expression" {
  assert_eq(interpret("sum [1, 2, 3, 4]"), "10")
}
```

## Project Layout

- `uiuaml.mbt`
  - public API and error type
- `syntax.mbt`
  - tokenizer, AST, and parser
- `value.mbt`
  - runtime values, array representation, rendering, and helpers
- `eval.mbt`
  - evaluator, environments, pervasive operations, and builtins
- `cmd/main/main.mbt`
  - command line interface

## Development

Useful commands:

```bash
moon info
moon fmt
moon test
```

## Scope and Non-Goals

UiuaML is still deliberately small. It does not currently aim to implement the
full Uiua language, and several larger features are still out of scope, such as:

- boxes and heterogeneous arrays
- modifiers and tacit stack syntax
- inversion and under-style transformations
- modules and larger source-file language features

The current focus is a compact, readable interpreter with a real array runtime
and enough expressive power to experiment with array programming in an
ML-flavored surface language.
