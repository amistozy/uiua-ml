///|
fn default_env() -> Env {
  @hashmap.new()
  |> bind_builtin("range", 1)
  |> bind_builtin("iota", 1)
  |> bind_builtin("map", 2)
  |> bind_builtin("each", 2)
  |> bind_builtin("filter", 2)
  |> bind_builtin("zip", 3)
  |> bind_builtin("reduce", 3)
  |> bind_builtin("scan", 3)
  |> bind_builtin("shape", 1)
  |> bind_builtin("rank", 1)
  |> bind_builtin("sum", 1)
  |> bind_builtin("any", 1)
  |> bind_builtin("all", 1)
  |> bind_builtin("count", 1)
  |> bind_builtin("where", 1)
  |> bind_builtin("first", 1)
  |> bind_builtin("last", 1)
  |> bind_builtin("reverse", 1)
  |> bind_builtin("deshape", 1)
  |> bind_builtin("len", 1)
  |> bind_builtin("reshape", 2)
  |> bind_builtin("take", 2)
  |> bind_builtin("drop", 2)
  |> bind_builtin("pick", 2)
  |> bind_builtin("select", 2)
  |> bind_builtin("keep", 2)
  |> bind_builtin("windows", 2)
  |> bind_builtin("orient", 2)
  |> bind_builtin("rotate", 2)
  |> bind_builtin("transpose", 1)
  |> bind_builtin("append", 2)
}

///|
fn bind_builtin(env : Env, name : String, arity : Int) -> Env {
  env.add(name, Value::Builtin(name, arity, []))
}

///|
fn eval(expr : Expr, env : Env) -> Value raise UiuaMLError {
  eval_with_fill(expr, env, None)
}

///|
fn eval_with_fill(
  expr : Expr,
  env : Env,
  fill : Value?,
) -> Value raise UiuaMLError {
  match expr {
    Expr::Number(n) => Value::Num(n)
    Expr::Bool(b) => Value::Bool(b)
    Expr::Var(name) =>
      match env.get(name) {
        Some(value) => value
        None => fail("Unbound name: \{name}")
      }
    Expr::ArrayLit(items) => {
      let values = Array::new(capacity=items.length())
      for item in items {
        values.push(eval_with_fill(item, env, fill))
      }
      array_from_items(values)
    }
    Expr::Let(name, value_expr, body) => {
      let next_env = env.add(name, eval_with_fill(value_expr, env, fill))
      eval_with_fill(body, next_env, fill)
    }
    Expr::Fill(fill_expr, body) => {
      let fill_value = eval_with_fill(fill_expr, env, fill)
      eval_with_fill(body, env, Some(fill_value))
    }
    Expr::If(cond, on_true, on_false) =>
      if truthy(eval_with_fill(cond, env, fill)) {
        eval_with_fill(on_true, env, fill)
      } else {
        eval_with_fill(on_false, env, fill)
      }
    Expr::Fun(param, body) => Value::Closure({ param, body, env })
    Expr::Call(callee, arg) =>
      apply(
        eval_with_fill(callee, env, fill),
        eval_with_fill(arg, env, fill),
        fill,
      )
    Expr::Unary(op, inner) => eval_unary(op, eval_with_fill(inner, env, fill))
    Expr::Binary(op, lhs, rhs) =>
      eval_binary(
        op,
        eval_with_fill(lhs, env, fill),
        eval_with_fill(rhs, env, fill),
      )
  }
}

///|
fn truthy(value : Value) -> Bool {
  match value {
    Value::Bool(b) => b
    Value::Num(n) => n != 0.0
    Value::Array(array) => array.element_count() != 0
    Value::Closure(_) | Value::Builtin(_, _, _) => true
  }
}

///|
fn apply(
  fn_value : Value,
  arg : Value,
  fill : Value?,
) -> Value raise UiuaMLError {
  match fn_value {
    Value::Closure(closure) => {
      let next_env = closure.env.add(closure.param, arg)
      eval_with_fill(closure.body, next_env, fill)
    }
    Value::Builtin(name, arity, captured) => {
      let args = captured.copy()
      args.push(arg)
      if args.length() == arity {
        run_builtin(name, args, fill)
      } else {
        Value::Builtin(name, arity, args)
      }
    }
    _ => fail("Attempted to call a non-function value")
  }
}

///|
fn eval_unary(op : String, value : Value) -> Value raise UiuaMLError {
  match op {
    "-" => broadcast_unary(value, n => Value::Num(-n))
    _ => fail("Unknown unary operator: \{op}")
  }
}

///|
fn eval_binary(
  op : String,
  lhs : Value,
  rhs : Value,
) -> Value raise UiuaMLError {
  match op {
    "+" => broadcast_numeric(lhs, rhs, (a, b) => a + b)
    "-" => broadcast_numeric(lhs, rhs, (a, b) => a - b)
    "*" => broadcast_numeric(lhs, rhs, (a, b) => a * b)
    "/" => broadcast_numeric(lhs, rhs, (a, b) => a / b)
    "==" => broadcast_compare(lhs, rhs, (a, b) => a == b, deep_equal)
    "!=" =>
      negate_bools(broadcast_compare(lhs, rhs, (a, b) => a == b, deep_equal))
    "<" => broadcast_compare(lhs, rhs, (a, b) => a < b, ordering_compare_error)
    "<=" =>
      broadcast_compare(lhs, rhs, (a, b) => a <= b, ordering_compare_error)
    ">" => broadcast_compare(lhs, rhs, (a, b) => a > b, ordering_compare_error)
    ">=" =>
      broadcast_compare(lhs, rhs, (a, b) => a >= b, ordering_compare_error)
    _ => fail("Unknown binary operator: \{op}")
  }
}

///|
fn ordering_compare_error(_lhs : Value, _rhs : Value) -> Bool raise UiuaMLError {
  fail("Ordering comparisons expect numbers or arrays of numbers")
}

///|
fn negate_bools(value : Value) -> Value raise UiuaMLError {
  match value {
    Value::Bool(b) => Value::Bool(!b)
    Value::Array(array) => {
      let result = Array::new(capacity=array.element_count())
      for item in array.data {
        result.push(negate_bools(item))
      }
      Value::Array(UiArray::{ shape: array.shape, data: result })
    }
    _ => fail("Expected boolean result")
  }
}

///|
fn broadcast_unary(
  value : Value,
  f : (Double) -> Value,
) -> Value raise UiuaMLError {
  match value {
    Value::Num(n) => f(n)
    Value::Array(array) => {
      let result = Array::new(capacity=array.element_count())
      for item in array.data {
        result.push(broadcast_unary(item, f))
      }
      Value::Array(UiArray::{ shape: array.shape, data: result })
    }
    _ => fail("Numeric operation expects numbers or arrays of numbers")
  }
}

///|
fn broadcast_numeric(
  lhs : Value,
  rhs : Value,
  f : (Double, Double) -> Double,
) -> Value raise UiuaMLError {
  pervade(lhs, rhs, (left, right) => {
    guard left is Value::Num(a) && right is Value::Num(b) else {
      fail("Numeric operation expects numbers or arrays of numbers")
    }
    Value::Num(f(a, b))
  })
}

///|
fn broadcast_compare(
  lhs : Value,
  rhs : Value,
  number_cmp : (Double, Double) -> Bool,
  scalar_cmp : (Value, Value) -> Bool raise UiuaMLError,
) -> Value raise UiuaMLError {
  pervade(lhs, rhs, (left, right) => {
    match (left, right) {
      (Value::Num(a), Value::Num(b)) => Value::Bool(number_cmp(a, b))
      _ => Value::Bool(scalar_cmp(left, right))
    }
  })
}

///|
fn pervade(
  lhs : Value,
  rhs : Value,
  op_scalar : (Value, Value) -> Value raise UiuaMLError,
) -> Value raise UiuaMLError {
  match (lhs, rhs) {
    (Value::Array(left), Value::Array(right)) =>
      pervade_arrays(left, right, op_scalar)
    (Value::Array(array), scalar) => map_array_left(array, scalar, op_scalar)
    (scalar, Value::Array(array)) => map_array_right(scalar, array, op_scalar)
    _ => op_scalar(lhs, rhs)
  }
}

///|
fn map_array_left(
  array : UiArray,
  scalar : Value,
  op_scalar : (Value, Value) -> Value raise UiuaMLError,
) -> Value raise UiuaMLError {
  let data = Array::new(capacity=array.element_count())
  for item in array.data {
    data.push(op_scalar(item, scalar))
  }
  Value::Array(UiArray::{ shape: array.shape, data })
}

///|
fn map_array_right(
  scalar : Value,
  array : UiArray,
  op_scalar : (Value, Value) -> Value raise UiuaMLError,
) -> Value raise UiuaMLError {
  let data = Array::new(capacity=array.element_count())
  for item in array.data {
    data.push(op_scalar(scalar, item))
  }
  Value::Array(UiArray::{ shape: array.shape, data })
}

///|
fn pervade_arrays(
  lhs : UiArray,
  rhs : UiArray,
  op_scalar : (Value, Value) -> Value raise UiuaMLError,
) -> Value raise UiuaMLError {
  if lhs.shape == rhs.shape {
    let data = Array::new(capacity=lhs.element_count())
    let mut i = 0
    while i < lhs.element_count() {
      data.push(op_scalar(lhs.data[i], rhs.data[i]))
      i = i + 1
    }
    return Value::Array(UiArray::{ shape: lhs.shape, data })
  }
  if shape_is_prefix(lhs.shape, rhs.shape) {
    let chunk = suffix_element_count(rhs.shape, lhs.rank())
    let data = Array::new(capacity=rhs.element_count())
    let mut i = 0
    while i < lhs.element_count() {
      let mut j = 0
      while j < chunk {
        data.push(op_scalar(lhs.data[i], rhs.data[i * chunk + j]))
        j = j + 1
      }
      i = i + 1
    }
    return Value::Array(UiArray::{ shape: rhs.shape, data })
  }
  if shape_is_prefix(rhs.shape, lhs.shape) {
    let chunk = suffix_element_count(lhs.shape, rhs.rank())
    let data = Array::new(capacity=lhs.element_count())
    let mut i = 0
    while i < rhs.element_count() {
      let mut j = 0
      while j < chunk {
        data.push(op_scalar(lhs.data[i * chunk + j], rhs.data[i]))
        j = j + 1
      }
      i = i + 1
    }
    return Value::Array(UiArray::{ shape: lhs.shape, data })
  }
  fail_shape_mismatch("pervasive operation", lhs.shape, rhs.shape)
}

///|
fn run_builtin(
  name : String,
  args : Array[Value],
  fill : Value?,
) -> Value raise UiuaMLError {
  match name {
    "range" | "iota" => builtin_range(args[0])
    "map" | "each" => builtin_map(args[0], args[1], fill)
    "filter" => builtin_filter(args[0], args[1], fill)
    "zip" => builtin_zip(args[0], args[1], args[2], fill)
    "reduce" => builtin_reduce(args[0], args[1], args[2], fill)
    "scan" => builtin_scan(args[0], args[1], args[2], fill)
    "shape" => builtin_shape(args[0])
    "rank" => builtin_rank(args[0])
    "sum" => Value::Num(sum_numbers(args[0]))
    "any" => builtin_any(args[0])
    "all" => builtin_all(args[0])
    "count" => builtin_count(args[0])
    "where" => builtin_where(args[0])
    "first" => builtin_first(args[0])
    "last" => builtin_last(args[0])
    "reverse" => builtin_reverse(args[0])
    "deshape" => builtin_deshape(args[0])
    "len" => builtin_len(args[0])
    "reshape" => builtin_reshape(args[0], args[1], fill)
    "take" => builtin_take(args[0], args[1], fill)
    "drop" => builtin_drop(args[0], args[1], fill)
    "pick" => builtin_pick(args[0], args[1], fill)
    "select" => builtin_select(args[0], args[1], fill)
    "keep" => builtin_keep(args[0], args[1])
    "windows" => builtin_windows(args[0], args[1], fill)
    "orient" => builtin_orient(args[0], args[1])
    "rotate" => builtin_rotate(args[0], args[1], fill)
    "transpose" => builtin_transpose(args[0])
    "append" => builtin_append(args[0], args[1])
    _ => fail("Unknown builtin: \{name}")
  }
}

///|
fn builtin_range(arg : Value) -> Value raise UiuaMLError {
  let n = as_nat(arg)
  let items = Array::new(capacity=n)
  let mut i = 0
  while i < n {
    items.push(Value::Num(Double::from_int(i)))
    i = i + 1
  }
  make_array([n], items)
}

///|
fn builtin_shape(arg : Value) -> Value raise UiuaMLError {
  let dims = infer_shape(arg)
  let data = Array::new(capacity=dims.length())
  for dim in dims {
    data.push(Value::Num(Double::from_int(dim)))
  }
  make_array([data.length()], data)
}

///|
fn builtin_map(
  fn_value : Value,
  arg : Value,
  fill : Value?,
) -> Value raise UiuaMLError {
  match arg {
    Value::Array(array) => {
      let mapped = Array::new(capacity=array.row_count())
      let mut row = 0
      while row < array.row_count() {
        mapped.push(apply(fn_value, array.row_value(row), fill))
        row = row + 1
      }
      array_from_items(mapped)
    }
    _ => apply(fn_value, arg, fill)
  }
}

///|
fn builtin_filter(
  fn_value : Value,
  arg : Value,
  fill : Value?,
) -> Value raise UiuaMLError {
  match arg {
    Value::Array(array) => {
      let selected = Array::new(capacity=array.row_count())
      let mut row = 0
      while row < array.row_count() {
        if truthy(apply(fn_value, array.row_value(row), fill)) {
          selected.push(row)
        }
        row = row + 1
      }
      Value::Array(array.select_rows(selected))
    }
    _ => fail("filter expects an array")
  }
}

///|
fn apply_binary_fn(
  fn_value : Value,
  lhs : Value,
  rhs : Value,
  fill : Value?,
) -> Value raise UiuaMLError {
  apply(apply(fn_value, lhs, fill), rhs, fill)
}

///|
fn builtin_zip(
  fn_value : Value,
  lhs : Value,
  rhs : Value,
  fill : Value?,
) -> Value raise UiuaMLError {
  match (lhs, rhs) {
    (Value::Array(xs), Value::Array(ys)) =>
      if xs.row_count() == ys.row_count() {
        let zipped = Array::new(capacity=xs.row_count())
        let mut row = 0
        while row < xs.row_count() {
          zipped.push(
            apply_binary_fn(
              fn_value,
              xs.row_value(row),
              ys.row_value(row),
              fill,
            ),
          )
          row = row + 1
        }
        array_from_items(zipped)
      } else if xs.row_count() == 1 {
        let left = xs.row_value(0)
        let zipped = Array::new(capacity=ys.row_count())
        let mut row = 0
        while row < ys.row_count() {
          zipped.push(apply_binary_fn(fn_value, left, ys.row_value(row), fill))
          row = row + 1
        }
        array_from_items(zipped)
      } else if ys.row_count() == 1 {
        let right = ys.row_value(0)
        let zipped = Array::new(capacity=xs.row_count())
        let mut row = 0
        while row < xs.row_count() {
          zipped.push(apply_binary_fn(fn_value, xs.row_value(row), right, fill))
          row = row + 1
        }
        array_from_items(zipped)
      } else {
        fail(
          "zip expects arrays with the same number of rows or a single row to broadcast",
        )
      }
    (Value::Array(xs), scalar) => {
      let zipped = Array::new(capacity=xs.row_count())
      let mut row = 0
      while row < xs.row_count() {
        zipped.push(apply_binary_fn(fn_value, xs.row_value(row), scalar, fill))
        row = row + 1
      }
      array_from_items(zipped)
    }
    (scalar, Value::Array(ys)) => {
      let zipped = Array::new(capacity=ys.row_count())
      let mut row = 0
      while row < ys.row_count() {
        zipped.push(apply_binary_fn(fn_value, scalar, ys.row_value(row), fill))
        row = row + 1
      }
      array_from_items(zipped)
    }
    _ => apply_binary_fn(fn_value, lhs, rhs, fill)
  }
}

///|
fn builtin_reduce(
  fn_value : Value,
  init : Value,
  arg : Value,
  fill : Value?,
) -> Value raise UiuaMLError {
  match arg {
    Value::Array(array) => {
      let mut acc = init
      let mut row = 0
      while row < array.row_count() {
        acc = apply(apply(fn_value, acc, fill), array.row_value(row), fill)
        row = row + 1
      }
      acc
    }
    _ => apply(apply(fn_value, init, fill), arg, fill)
  }
}

///|
fn builtin_scan(
  fn_value : Value,
  init : Value,
  arg : Value,
  fill : Value?,
) -> Value raise UiuaMLError {
  match arg {
    Value::Array(array) => {
      if array.row_count() == 0 {
        return empty_rows_like(init)
      }
      let scanned = Array::new(capacity=array.row_count())
      let mut acc = init
      let mut row = 0
      while row < array.row_count() {
        acc = apply(apply(fn_value, acc, fill), array.row_value(row), fill)
        scanned.push(acc)
        row = row + 1
      }
      array_from_items(scanned)
    }
    _ => apply(apply(fn_value, init, fill), arg, fill)
  }
}

///|
fn builtin_rank(arg : Value) -> Value {
  Value::Num(Double::from_int(infer_shape(arg).length()))
}

///|
fn builtin_any(arg : Value) -> Value {
  Value::Bool(any_truthy(arg))
}

///|
fn builtin_all(arg : Value) -> Value {
  Value::Bool(all_truthy(arg))
}

///|
fn builtin_count(arg : Value) -> Value {
  Value::Num(Double::from_int(count_truthy(arg)))
}

///|
fn empty_rows_like(value : Value) -> Value raise UiuaMLError {
  let shape = [0]
  for dim in infer_shape(value) {
    shape.push(dim)
  }
  make_array(shape, [])
}

///|
fn builtin_where(arg : Value) -> Value raise UiuaMLError {
  match arg {
    Value::Bool(b) =>
      if b {
        make_array([1], [Value::Num(0.0)])
      } else {
        make_array([0], [])
      }
    Value::Num(n) =>
      if n != 0.0 {
        make_array([1], [Value::Num(0.0)])
      } else {
        make_array([0], [])
      }
    Value::Array(array) => {
      let true_count = array.data.fold(init=0, (count, item) => {
        if truthy(item) {
          count + 1
        } else {
          count
        }
      })
      if array.rank() <= 1 {
        let data = Array::new(capacity=true_count)
        let mut i = 0
        while i < array.element_count() {
          if truthy(array.data[i]) {
            data.push(Value::Num(Double::from_int(i)))
          }
          i = i + 1
        }
        make_array([data.length()], data)
      } else {
        let rank = array.rank()
        let data = Array::new(capacity=true_count * rank)
        let mut flat = 0
        while flat < array.element_count() {
          if truthy(array.data[flat]) {
            for index in flat_to_indices(array.shape, flat) {
              data.push(Value::Num(Double::from_int(index)))
            }
          }
          flat = flat + 1
        }
        make_array([true_count, rank], data)
      }
    }
    _ => fail("where expects a boolean or numeric array")
  }
}

///|
fn builtin_first(arg : Value) -> Value raise UiuaMLError {
  match arg {
    Value::Array(array) =>
      if array.row_count() == 0 {
        fail("first expects a non-empty array")
      } else {
        array.row_value(0)
      }
    _ => fail("first expects an array")
  }
}

///|
fn builtin_last(arg : Value) -> Value raise UiuaMLError {
  match arg {
    Value::Array(array) =>
      if array.row_count() == 0 {
        fail("last expects a non-empty array")
      } else {
        array.row_value(array.row_count() - 1)
      }
    _ => fail("last expects an array")
  }
}

///|
fn builtin_reverse(arg : Value) -> Value raise UiuaMLError {
  match arg {
    Value::Array(array) => Value::Array(array.reversed())
    _ => fail("reverse expects an array")
  }
}

///|
fn builtin_deshape(arg : Value) -> Value raise UiuaMLError {
  let flat = flat_values(arg)
  make_array([flat.length()], flat)
}

///|
fn builtin_len(arg : Value) -> Value {
  match arg {
    Value::Array(array) => Value::Num(Double::from_int(array.row_count()))
    _ => Value::Num(1.0)
  }
}

///|
fn builtin_append(lhs : Value, rhs : Value) -> Value raise UiuaMLError {
  match (lhs, rhs) {
    (Value::Array(xs), Value::Array(ys)) => Value::Array(xs.append_rows(ys))
    _ => fail("append expects two arrays")
  }
}

///|
fn builtin_reshape(
  shape_value : Value,
  data_value : Value,
  fill : Value?,
) -> Value raise UiuaMLError {
  let shape = shape_to_dims(shape_value)
  let flat = flat_values(data_value)
  guard !flat.is_empty() else { fail("reshape cannot use empty data") }
  let count = element_count_for_shape(shape)
  if shape.is_empty() {
    return flat[0]
  }
  let data = Array::new(capacity=count)
  let mut i = 0
  while i < count.min(flat.length()) {
    data.push(flat[i])
    i = i + 1
  }
  if count > flat.length() {
    guard fill is Some(fill_value) else {
      let mut j = i
      while j < count {
        data.push(flat[j % flat.length()])
        j = j + 1
      }
      return make_array(shape, data)
    }
    let fill_scalar = expect_fill_scalar(fill_value, "reshape")
    let mut j = i
    while j < count {
      data.push(fill_scalar)
      j = j + 1
    }
  } else if fill is Some(_) && count < flat.length() {
    fail(
      "reshape with fill cannot shrink \{flat.length()} items into shape \{render_shape(shape)}",
    )
  }
  make_array(shape, data)
}

///|
fn builtin_take(
  amount : Value,
  arg : Value,
  fill : Value?,
) -> Value raise UiuaMLError {
  let n = as_int(amount)
  match arg {
    Value::Array(array) => {
      let next = match fill {
        Some(fill_value) => array.take_rows_filled(n, fill_value)
        None => array.take_rows(n)
      }
      Value::Array(next)
    }
    _ => fail("take expects an array")
  }
}

///|
fn builtin_drop(
  amount : Value,
  arg : Value,
  fill : Value?,
) -> Value raise UiuaMLError {
  let n = as_int(amount)
  match arg {
    Value::Array(array) => {
      let next = match fill {
        Some(fill_value) => array.drop_rows_filled(n, fill_value)
        None => array.drop_rows(n)
      }
      Value::Array(next)
    }
    _ => fail("drop expects an array")
  }
}

///|
fn builtin_pick(
  index : Value,
  arg : Value,
  fill : Value?,
) -> Value raise UiuaMLError {
  let indices = as_index_vector(index, "pick")
  pick_from(arg, indices, fill)
}

///|
fn builtin_select(
  indices : Value,
  arg : Value,
  fill : Value?,
) -> Value raise UiuaMLError {
  let rows = as_index_vector(indices, "select")
  match arg {
    Value::Array(array) => {
      let next = match fill {
        Some(fill_value) => array.select_rows_filled(rows, fill_value)
        None => array.select_rows(rows)
      }
      Value::Array(next)
    }
    _ => fail("select expects an array")
  }
}

///|
fn builtin_keep(mask : Value, arg : Value) -> Value raise UiuaMLError {
  let rows = keep_indices(mask)
  match arg {
    Value::Array(array) => {
      guard rows.length() == array.row_count() else {
        fail(
          "keep mask length \{rows.length()} does not match \{array.row_count()} rows",
        )
      }
      let selected = Array::new()
      let mut i = 0
      while i < rows.length() {
        if rows[i] {
          selected.push(i)
        }
        i = i + 1
      }
      Value::Array(array.select_rows(selected))
    }
    _ => fail("keep expects an array")
  }
}

///|
fn builtin_windows(
  size : Value,
  arg : Value,
  fill : Value?,
) -> Value raise UiuaMLError {
  let n = as_int(size)
  match arg {
    Value::Array(array) => {
      let next = match fill {
        Some(fill_value) => array.window_rows_filled(n, fill_value)
        None => array.window_rows(n)
      }
      Value::Array(next)
    }
    _ => fail("windows expects an array")
  }
}

///|
fn builtin_orient(axes : Value, arg : Value) -> Value raise UiuaMLError {
  let indices = as_index_vector(axes, "orient")
  match arg {
    Value::Array(array) => Value::Array(array.oriented(indices))
    _ => fail("orient expects an array")
  }
}

///|
fn builtin_rotate(
  amount : Value,
  arg : Value,
  fill : Value?,
) -> Value raise UiuaMLError {
  let n = as_int(amount)
  match arg {
    Value::Array(array) => {
      let next = match fill {
        Some(fill_value) => array.rotated_rows_filled(n, fill_value)
        None => array.rotated_rows(n)
      }
      Value::Array(next)
    }
    _ => fail("rotate expects an array")
  }
}

///|
fn builtin_transpose(arg : Value) -> Value raise UiuaMLError {
  match arg {
    Value::Array(array) => Value::Array(array.transposed())
    _ => fail("transpose expects an array")
  }
}

///|
fn keep_indices(mask : Value) -> Array[Bool] raise UiuaMLError {
  match mask {
    Value::Bool(b) => [b]
    Value::Num(n) => [n != 0.0]
    Value::Array(array) => {
      guard array.rank() <= 1 else {
        fail("keep expects a boolean or numeric mask vector")
      }
      let result = Array::new(capacity=array.element_count())
      for item in array.data {
        result.push(truthy(item))
      }
      result
    }
    _ => fail("keep expects a boolean or numeric mask vector")
  }
}
