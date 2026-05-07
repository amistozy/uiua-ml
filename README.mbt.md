# `amistozy/uiuaml`

UiuaML is a small experimental array language implemented in MoonBit.

It is inspired by [Uiua](https://www.uiua.org/), but it uses an ML-like,
expression-oriented syntax instead of Uiua's tacit stack syntax. The current
goal is not to reimplement all of Uiua, but to build a compact interpreter with
a real array runtime, pervasive operations, and a growing set of
Uiua-flavored primitives.

## Highlights

UiuaML currently supports:

- ML-like expressions:
  - `let ... in ...`
  - `fun x -> ...`
  - function application
  - `if ... then ... else ...`
- Dynamic values:
  - numbers
  - booleans
  - arrays
  - closures
  - built-in functions with partial application
- Rectangular array literals such as `[1, 2, 3]` and `[[1, 2], [3, 4]]`
- A flat `shape + data` array runtime instead of nested list interpretation
- Pervasive arithmetic and comparisons with scalar and shape-prefix broadcasting
- A small but useful set of Uiua-inspired array primitives
- Higher-order array combinators for row-wise mapping, filtering, zipping, reduction, and scans
- A CLI with `eval` and `run` subcommands built with `argparse`

## Examples

### Core expressions

```text
let inc = fun x -> x + 1 in inc 41
let add = fun x -> fun y -> x + y in add 3 4
if sum [1, 1, 1] == 3 then 42 else 0
```

### Arrays and broadcasting

```text
[1, 2, 3] + 10
[1, 2, 3] + [10, 20, 30]
[10, 20] + [[3, 4, 5], [6, 7, 8]]
map (fun row -> sum row) [[1, 2], [3, 4], [5, 6]]
filter (fun x -> x > 2) [1, 2, 3, 4, 5]
zip (fun x -> fun y -> x + y) [1, 2, 3] [10, 20, 30]
reduce (fun acc -> fun x -> acc + x) 0 [1, 2, 3, 4]
scan (fun acc -> fun x -> acc + x) 0 [1, 2, 3, 4]
```

### Array-oriented built-ins

```text
shape [[1, 2], [3, 4]]
transpose [[1, 2, 3], [4, 5, 6]]
select (where [0, 1, 0, 1]) [2, 8, 3, 9]
windows 3 [1, 2, 3, 4, 5]
orient [1, 0] [[1, 2, 3], [4, 5, 6]]
```

## Built-ins

UiuaML currently provides the following built-ins.

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

### Aggregation and filtering

- `sum`
- `keep`
- `map`
- `each`
- `filter`
- `zip`
- `reduce`
- `scan`

## Array Model

UiuaML uses a flat array representation:

- every array has a `shape`
- all leaf elements are stored in row-major order
- arrays must be rectangular

This is much closer to Uiua's array model than interpreting arrays as arbitrary
nested lists. It makes shape-driven operations such as `reshape`, `transpose`,
`orient`, `windows`, `pick`, and broadcasting much easier to define precisely.

### Broadcasting

Binary arithmetic and comparison operators are pervasive:

- scalars broadcast across arrays
- arrays with the same shape combine element-wise
- arrays can also combine with a larger array when one shape is a prefix of the
  other

Examples:

```text
[1, 2, 3] + 10
[1, 2, 3] + [10, 20, 30]
[10, 20] + [[3, 4, 5], [6, 7, 8]]
```

## Syntax Notes

### Comments

Line comments start with `#`.

```text
let xs = range 4 # build a vector
in sum xs
```

### Negative numbers

Negative values work in ordinary expressions and builtin calls.

```text
take -2 [1, 2, 3, 4, 5]
drop -2 [1, 2, 3, 4, 5]
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

It tokenizes, parses, evaluates, and renders the final value.

Example:

```mbt nocheck
///|
test "interpret an expression" {
  assert_eq(interpret("sum [1, 2, 3, 4]"), "10")
}
```

## Project Layout

The interpreter is now split into a few focused files:

- `uiuaml.mbt`
  - public API and error type
- `syntax.mbt`
  - tokenizer, AST, and parser
- `value.mbt`
  - runtime values, flat arrays, rendering, and array helpers
- `eval.mbt`
  - evaluator, environment, pervasive operators, and built-ins
- `cmd/main/main.mbt`
  - command line interface

## Development

Useful commands:

```bash
moon info
moon fmt
moon test
```

## Current Scope

UiuaML is still intentionally small.

It does not aim to be a full Uiua implementation, and several advanced Uiua
features are still missing, including:

- boxes and heterogeneous arrays
- modifiers and tacit syntax
- fill semantics for more structural operations
- general inversion support
- modules and larger source-file language features

That said, the interpreter now has a real array runtime and enough primitives to
experiment with a meaningful subset of array programming ideas in an ML-like
surface language.
