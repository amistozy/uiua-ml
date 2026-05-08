# `amistozy/uiuaml`

UiuaML is a small experimental array language implemented in MoonBit.

It is inspired by [Uiua](https://www.uiua.org/), but it uses an
ML-flavored, expression-oriented syntax instead of Uiua's stack-based tacit
notation. The goal is not to reimplement all of Uiua. The goal is to explore a
compact, practical subset of array programming with:

- first-class functions
- rectangular arrays
- a flat row-major runtime
- scoped fill semantics
- shape-aware structural operators

## Status

UiuaML already supports a useful core language:

- `let ... in ...`
- `fun x -> ...`
- function application
- `if ... then ... else ...`
- `fill value in expr`
- numbers, booleans, arrays, closures, and builtins
- rectangular array literals such as `[1, 2, 3]` and `[[1, 2], [3, 4]]`
- pervasive arithmetic and comparison
- row-oriented higher-order array combinators
- multi-dimensional indexing and selection
- multi-axis structural transforms
- a small CLI and a public `interpret` API

## Quick Tour

### Basic expressions

```text
let inc = fun x -> x + 1 in inc 41
let add = fun x -> fun y -> x + y in add 3 4
if sum [1, 1, 1] == 3 then 42 else 0
```

### Pervasive arithmetic

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
keep [2, 1, 1] [1, 2, 3]
```

### Shape-driven programming

```text
range 5
range [2, 3]
shape [[1, 2], [3, 4]]
reshape [2, 3] [1, 2, 3, 4]
transpose [[1, 2, 3], [4, 5, 6]]
orient [1, 0] [[1, 2, 3], [4, 5, 6]]
rotate [1, 2] (reshape [4, 5] (range 20))
```

### Indexing and selection

```text
pick 2 [8, 3, 9, 2, 0]
pick [1, 1] [[1, 2, 3], [4, 5, 6]]
select [0, 2, 1, 1] [[1, 2], [3, 4], [5, 6]]
select (where [0, 1, 0, 1]) [2, 8, 3, 9]
```

### Fill scopes

```text
fill 0 in take 5 [1, 2, 3]
fill 0 in reshape [2, 3] [1, 2, 3, 4]
fill 0 in rotate [1, 2] (reshape [4, 5] (range 20))
fill [9, 9] in select [0, 9, -1] [[1, 2], [3, 4]]
```

## Core Ideas

### Flat array runtime

UiuaML uses a flat row-major representation.

- every array has an explicit shape
- leaf values live in one flat buffer
- arrays must be rectangular

This keeps the evaluator small and makes many structural operators easy to
define in terms of shape and flat indexing.

### Pervasion

Binary arithmetic and comparison operators are pervasive.

- scalars broadcast over arrays
- arrays of the same shape combine element-wise
- arrays also combine when one shape is a prefix of the other

Examples:

```text
[1, 2, 3] + 10
[1, 2, 3] + [10, 20, 30]
[10, 20] + [[3, 4, 5], [6, 7, 8]]
```

### Rows as the default iteration unit

Several builtins work row-wise along the leading axis.

- `map` and `each` apply a function to each row
- `filter` keeps rows whose predicate is truthy
- `zip` combines rows from two values
- `reduce` folds rows into an accumulator
- `scan` returns intermediate accumulator states
- `keep` repeats rows according to counts

For vectors, a row is a single element. For higher-rank arrays, a row is a
leading-axis slice.

## Builtins

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

### Aggregation and predicates

- `sum`
- `any`
- `all`
- `count`

### Higher-order operations

- `map`
- `each`
- `filter`
- `zip`
- `reduce`
- `scan`
- `keep`

## Semantics Notes

### `range`

`range` supports both scalar and vector input.

```text
range 5
range -5
range [3, 3]
range [-2, 3]
```

- a positive scalar creates `0 .. n-1`
- a negative scalar creates `-1, -2, ...`
- a vector creates a coordinate array
- negative dimensions reverse that axis in coordinate space

### `take`, `drop`, and `rotate`

These operators support both scalar and vector amounts.

```text
take 3 [1, 2, 3, 4, 5]
take [2, 3] (reshape [3, 4] (range 12))
drop [-2, -2] (reshape [3, 3] (range 9))
rotate [1, 2] (reshape [4, 5] (range 20))
```

With a vector amount, UiuaML applies the operation across multiple leading
axes.

### `keep`

`keep` uses count semantics rather than only boolean filtering.

```text
keep 3 [1, 2, 3]
keep [2, 1, 1] [1, 2, 3]
keep [1, 0, 1] (range 10)
fill [1, 2, 0] in keep [0, 4] (range 10)
```

- `0` drops a row
- `1` keeps it once
- `2` keeps it twice
- scalar counts repeat every row equally
- short count vectors repeat by default
- inside a fill scope, the fill value supplies the repeating tail pattern

### `pick` and `select`

`pick` indexes into values, while `select` chooses rows from arrays.

```text
pick [[1, 2], [0, 1]] [[1, 2, 3], [4, 5, 6]]
select [[0, 1], [1, 2], [2, 0]] [2, 3, 5, 7]
```

When the selector rank is greater than `1`, each selector row is treated as an
independent deeper access.

Without fill:

- negative indices count from the end
- out-of-bounds access raises an error

With fill:

- out-of-bounds indices yield the fill result
- filled structural operations become total over a larger input space

### Fill scopes

`fill value in expr` installs a temporary fill value for structural operations
inside `expr`.

This currently affects:

- `reshape`
- `take`
- `drop`
- `pick`
- `select`
- `rotate`
- `windows`
- `orient`
- `keep`

## Syntax Notes

### Comments

Line comments start with `#`.

```text
let xs = range 4 # build a vector
in sum xs
```

### Negative numbers

Negative literals work directly in expressions and builtin arguments.

```text
take -2 [1, 2, 3, 4, 5]
drop -2 [1, 2, 3, 4, 5]
range -5
rotate -1 [[1, 2], [3, 4], [5, 6]]
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

It tokenizes the source, parses it, evaluates it, and renders the resulting
value.

Example:

```mbt nocheck
///|
test "interpret an expression" {
  assert_eq(interpret("sum [1, 2, 3, 4]"), "10")
}
```

## Project Layout

- `uiuaml.mbt`: public API and error type
- `syntax.mbt`: tokenizer, AST, and parser
- `value.mbt`: runtime values, array storage, rendering, and shape helpers
- `eval.mbt`: evaluator, environments, fill handling, and builtins
- `cmd/main/main.mbt`: command line interface

## Development

Useful commands:

```bash
moon info
moon fmt
moon test
```

## Non-Goals

UiuaML is intentionally small. It currently does not aim to implement:

- the full Uiua language
- tacit stack syntax and modifiers
- boxes and heterogeneous arrays
- inversion and under-style transformations
- modules and larger source-file language features
