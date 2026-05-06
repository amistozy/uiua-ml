# amistozy/uiuaml

UiuaML is a small experimental array language implemented in MoonBit.
It borrows its array-oriented spirit from [Uiua](https://www.uiua.org/) while
using an ML-like surface syntax with dynamic values.

## Overview

UiuaML currently provides:

- ML-like expressions: `let ... in ...`, `fun x -> ...`, function application,
  and `if ... then ... else ...`
- Dynamic values: numbers, booleans, arrays, closures, and built-in functions
- Array literals such as `[1, 2, 3]`
- Element-wise arithmetic and comparison with scalar broadcasting
- A small set of Uiua-inspired array primitives

The current implementation is intentionally small and focused on being a
readable interpreter core rather than a full Uiua port.

## Language Sketch

### Basic expressions

```text
let inc = fun x -> x + 1 in inc 41
if 1 < 2 then 10 else 20
```

### Arrays and pervasive operations

```text
[1, 2, 3] + 10
[1, 2, 3] + [10, 20, 30]
sum [1, 2, 3, 4]
```

### Built-ins

The interpreter currently includes these built-ins:

- `range`
- `iota`
- `shape`
- `sum`
- `first`
- `reverse`
- `len`
- `reshape`
- `append`

Examples:

```text
range 5
shape [[1, 2], [3, 4]]
reshape [2, 3] [1, 2, 3, 4]
```

## CLI

The CLI is implemented with `moonbitlang/core/argparse`.

### Evaluate an expression

```bash
moon run cmd/main -- eval "sum [1, 2, 3, 4]"
```

### Run a source file

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

It parses, evaluates, and renders the result as a string.

Example:

```mbt nocheck
///|
test "interpret a simple expression" {
  assert_eq(interpret("sum [1, 2, 3, 4]"), "10")
}
```

## Development

Format, refresh package interface files, and run tests with:

```bash
moon info
moon fmt
moon test
```

## Current Limitations

- This is not a full Uiua implementation.
- The array model is currently simple nested arrays rather than a dedicated
  rank/shape runtime.
- The language is dynamically typed and intentionally minimal.
- Error reporting is functional but still basic.
