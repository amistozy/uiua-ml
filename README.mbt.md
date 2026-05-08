# `amistozy/uiuaml`

UiuaML is a small experimental array language implemented in MoonBit.

It is inspired by [Uiua](https://www.uiua.org/), but it uses an
expression-oriented, ML-flavored syntax instead of Uiua's stack-based tacit
notation. The project is intentionally narrow in scope: it explores a compact
subset of array programming with first-class functions, rectangular arrays, a
flat row-major runtime, and shape-aware structural operations.

## Overview

UiuaML currently includes:

- lexical scoping with `let ... in ...`
- first-class functions with curried application
- multi-parameter function sugar such as `fun x y -> ...`
- function-definition sugar such as `let add x y = ... in ...`
- conditionals with `if ... then ... else ...`
- fill scopes with `fill value in expr`
- rectangular array literals with optional trailing commas
- pervasive arithmetic and comparison
- row-oriented higher-order array combinators
- multidimensional indexing and selection
- structural and axis-aware array transforms
- source-aware parse and runtime error messages
- a CLI and a public `interpret` API

## Examples

### Basic expressions

```text
let inc = fun x -> x + 1 in inc 41
let add x y = x + y in add 3 4
if sum [1, 1, 1] == 3 then 42 else 0
```

### Arrays and pervasion

```text
[1, 2, 3] + 10
[1, 2, 3] + [10, 20, 30]
[10, 20] + [[3, 4, 5], [6, 7, 8]]
```

### Higher-order array programming

```text
map (fun x -> x + 1) [1, 2, 3]
filter (fun x -> x > 2) [1, 2, 3, 4, 5]
table (fun x y -> x + y) [1, 2, 3] [10, 20, 30]
zip (fun x y -> x + y) [1, 2, 3] [10, 20, 30]
reduce (fun acc x -> acc + x) 0 [1, 2, 3, 4]
scan (fun acc x -> acc + x) 0 [1, 2, 3, 4]
keep [2, 1, 1] [1, 2, 3]
```

### Shape-driven operations

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

### Flat row-major arrays

UiuaML stores arrays as:

- an explicit shape
- one flat buffer of leaf values
- a guarantee that literals are rectangular

This keeps the runtime small and makes many structural operators easy to
express in terms of shape and flat indexing.

### Pervasive operators

Arithmetic and comparison operators are pervasive:

- scalars broadcast over arrays
- arrays of equal shape combine element-wise
- arrays can also combine when one shape is a prefix of the other

For example:

```text
[1, 2, 3] + 10
[1, 2, 3] + [10, 20, 30]
[10, 20] + [[3, 4, 5], [6, 7, 8]]
```

### Rows as the default iteration unit

Several builtins iterate over rows of the leading axis:

- `map` and `each`
- `filter`
- `table`
- `zip`
- `reduce`
- `scan`
- `keep`

For a vector, a row is a single element. For higher-rank arrays, a row is a
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

### Structural operations

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
- `table`
- `filter`
- `zip`
- `reduce`
- `scan`
- `keep`

## Semantics Notes

### `range`

`range` accepts either a scalar or a vector of dimensions:

```text
range 5
range -5
range [3, 3]
range [-2, 3]
```

- a positive scalar produces `0 .. n-1`
- a negative scalar produces `-1, -2, ...`
- a dimension vector produces a coordinate array
- negative dimensions reverse that axis in coordinate space

### `take`, `drop`, and `rotate`

These builtins accept either a scalar amount or a vector of per-axis amounts:

```text
take 3 [1, 2, 3, 4, 5]
take [2, 3] (reshape [3, 4] (range 12))
drop [-2, -2] (reshape [3, 3] (range 9))
rotate [1, 2] (reshape [4, 5] (range 20))
```

### `keep`

`keep` uses count semantics:

```text
keep 3 [1, 2, 3]
keep [2, 1, 1] [1, 2, 3]
keep [1, 0, 1] (range 10)
fill [1, 2, 0] in keep [0, 4] (range 10)
```

- `0` drops a row
- `1` keeps it once
- `2` keeps it twice
- a scalar count repeats every row equally
- a short count vector repeats by default
- inside a fill scope, the fill value supplies the repeating tail pattern

### `pick` and `select`

`pick` performs indexing into a value, while `select` chooses rows:

```text
pick [[1, 2], [0, 1]] [[1, 2, 3], [4, 5, 6]]
select [[0, 1], [1, 2], [2, 0]] [2, 3, 5, 7]
```

Without fill:

- negative indices count from the end
- out-of-bounds access raises an error

With fill:

- out-of-bounds access yields the fill result
- structural operators become total over a larger input space

## Syntax Notes

### Comments

Line comments start with `#`.

```text
let xs = range 4 # build a vector
in sum xs
```

### Multi-parameter function sugar

UiuaML supports curried functions directly, and also supports a more convenient
surface syntax:

```text
fun x y -> x + y
let add x y = x + y in add 3 4
```

These forms are desugared into nested one-argument functions.

### Array trailing commas

Array literals may end with a trailing comma:

```text
[1, 2, 3,]
[[1, 2], [3, 4],]
```

### Negative numbers

Negative numeric literals work directly in expressions and builtin arguments:

```text
take -2 [1, 2, 3, 4, 5]
drop -2 [1, 2, 3, 4, 5]
range -5
rotate -1 [[1, 2], [3, 4], [5, 6]]
```

## Error Reporting

UiuaML reports parse and runtime errors with source locations and a short code
snippet. For example, shape mismatches, out-of-bounds indexing, and malformed
syntax all point back to the relevant span in the input program.

## CLI

The CLI lives in `cmd/main` and uses `moonbitlang/core/argparse`.

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

The main public entry point is:

```mbt nocheck
pub fn interpret(source : StringView) -> String raise UiuaMLError
```

It tokenizes the input, parses it, evaluates it, and renders the resulting
value.

Example:

```mbt nocheck
///|
test "interpret an expression" {
  assert_eq(interpret("sum [1, 2, 3, 4]"), "10")
}
```

## Project Layout

- `uiuaml.mbt`: public API, error rendering, and source spans
- `syntax.mbt`: tokenizer, AST, and parser
- `value.mbt`: runtime values, array storage, rendering, and shape helpers
- `eval.mbt`: evaluator, environments, fill handling, and builtins
- `cmd/main/main.mbt`: command-line interface

## Development

Useful commands:

```bash
moon info
moon fmt
moon test
```

## Non-Goals

UiuaML is intentionally small. It does not currently aim to implement:

- the full Uiua language
- tacit stack syntax and modifiers
- boxes and heterogeneous arrays
- inversion and under-style transformations
- modules or a larger source-file language
