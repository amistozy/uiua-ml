///|
type Env = @hashmap.HashMap[String, Value]

///|
priv struct Closure {
  param : String
  body : Expr
  env : Env
}

///|
priv struct UiArray {
  shape : Array[Int]
  data : Array[Value]
}

///|
priv enum Value {
  Num(Double)
  Bool(Bool)
  Array(UiArray)
  Closure(Closure)
  Builtin(String, Int, Array[Value])
}

///|
fn shape_is_prefix(prefix : Array[Int], shape : Array[Int]) -> Bool {
  if prefix.length() > shape.length() {
    return false
  }
  let mut i = 0
  while i < prefix.length() {
    if prefix[i] != shape[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn suffix_element_count(shape : Array[Int], start : Int) -> Int {
  element_count_for_shape(shape[start:].to_owned())
}

///|
fn render_shape(shape : Array[Int]) -> String {
  let body = shape.map(n => n.to_string()).join(" ")
  "[\{body}]"
}

///|
fn deep_equal(lhs : Value, rhs : Value) -> Bool raise UiuaMLError {
  match (lhs, rhs) {
    (Value::Num(a), Value::Num(b)) => a == b
    (Value::Bool(a), Value::Bool(b)) => a == b
    (Value::Array(xs), Value::Array(ys)) => {
      if xs.shape != ys.shape || xs.element_count() != ys.element_count() {
        return false
      }
      let mut i = 0
      while i < xs.element_count() {
        if !deep_equal(xs.data[i], ys.data[i]) {
          return false
        }
        i = i + 1
      }
      true
    }
    (Value::Closure(_), Value::Closure(_)) => false
    (Value::Builtin(_, _, _), Value::Builtin(_, _, _)) => false
    _ => false
  }
}

///|
fn shape_to_dims(value : Value) -> Array[Int] raise UiuaMLError {
  match value {
    Value::Array(array) => {
      guard array.rank() <= 1 else {
        fail("reshape expects shape to be a vector of integers")
      }
      let dims = Array::new(capacity=array.element_count())
      for item in array.data {
        dims.push(as_nat(item))
      }
      dims
    }
    _ => fail("reshape expects shape to be an array of integers")
  }
}

///|
fn infer_shape(value : Value) -> Array[Int] {
  match value {
    Value::Array(array) => array.shape
    _ => []
  }
}

///|
fn flat_values(value : Value) -> Array[Value] {
  match value {
    Value::Array(array) => array.data
    _ => [value]
  }
}

///|
fn sum_numbers(value : Value) -> Double raise UiuaMLError {
  match value {
    Value::Num(n) => n
    Value::Bool(_) => fail("sum expects numbers or arrays of numbers")
    Value::Array(array) =>
      array.data.fold(init=0.0, (acc, item) => acc + sum_numbers(item))
    _ => fail("sum expects numbers or arrays of numbers")
  }
}

///|
fn make_array(
  shape : Array[Int],
  data : Array[Value],
) -> Value raise UiuaMLError {
  validate_shape(shape, data.length())
  Value::Array(UiArray::{ shape, data })
}

///|
fn validate_shape(shape : Array[Int], len : Int) -> Unit raise UiuaMLError {
  guard element_count_for_shape(shape) == len else {
    fail("Shape \{render_shape(shape)} does not match element count \{len}")
  }
}

///|
fn element_count_for_shape(shape : Array[Int]) -> Int {
  if shape.is_empty() {
    return 1
  }
  let mut count = 1
  for dim in shape {
    count = count * dim
  }
  count
}

///|
fn array_from_items(items : Array[Value]) -> Value raise UiuaMLError {
  if items.is_empty() {
    return make_array([0], [])
  }
  let child_shape = infer_shape(items[0])
  let data = Array::new()
  for item in items {
    guard infer_shape(item) == child_shape else {
      fail("Array literal expects rectangular rows")
    }
    for leaf in flat_values(item) {
      data.push(leaf)
    }
  }
  let shape = [
    if child_shape.is_empty() {
      data.length()
    } else {
      data.length() / element_count_for_shape(child_shape)
    },
  ]
  for dim in child_shape {
    shape.push(dim)
  }
  make_array(shape, data)
}

///|
fn UiArray::element_count(self : UiArray) -> Int {
  self.data.length()
}

///|
fn UiArray::rank(self : UiArray) -> Int {
  self.shape.length()
}

///|
fn UiArray::row_count(self : UiArray) -> Int {
  if self.shape.is_empty() {
    1
  } else {
    self.shape[0]
  }
}

///|
fn UiArray::row_len(self : UiArray) -> Int {
  suffix_element_count(self.shape, 1)
}

///|
fn UiArray::row_shape(self : UiArray) -> Array[Int] {
  if self.rank() <= 1 {
    []
  } else {
    self.shape[1:].to_owned()
  }
}

///|
fn UiArray::row_value(self : UiArray, row : Int) -> Value {
  if row < 0 || row >= self.row_count() {
    panic()
  }
  if self.rank() <= 1 {
    self.data[row]
  } else {
    let row_len = self.row_len()
    let start = row * row_len
    let data = Array::new(capacity=row_len)
    let mut i = 0
    while i < row_len {
      data.push(self.data[start + i])
      i = i + 1
    }
    make_array(self.row_shape(), data) catch {
      _ => panic()
    }
  }
}

///|
fn UiArray::reversed(self : UiArray) -> UiArray {
  if self.rank() <= 1 {
    return { shape: self.shape, data: self.data.rev() }
  }
  let row_len = self.row_len()
  let data = Array::new(capacity=self.element_count())
  let mut row = self.row_count() - 1
  while row >= 0 {
    let start = row * row_len
    let mut i = 0
    while i < row_len {
      data.push(self.data[start + i])
      i = i + 1
    }
    if row == 0 {
      break
    }
    row = row - 1
  }
  { shape: self.shape, data }
}

///|
fn UiArray::append_rows(
  self : UiArray,
  other : UiArray,
) -> UiArray raise UiuaMLError {
  guard self.row_shape() == other.row_shape() else {
    fail(
      "append expects matching row shapes: \{render_shape(self.row_shape())} vs \{render_shape(other.row_shape())}",
    )
  }
  let data = self.data.copy()
  for item in other.data {
    data.push(item)
  }
  let shape = [self.row_count() + other.row_count()]
  for dim in self.row_shape() {
    shape.push(dim)
  }
  validate_shape(shape, data.length())
  { shape, data }
}

///|
fn UiArray::take_rows(self : UiArray, n : Int) -> UiArray {
  if self.rank() == 0 {
    return if n == 0 { { shape: [0], data: [] } } else { self }
  }
  let rows = self.row_count()
  let count = if n >= 0 { n.min(rows) } else { (-n).min(rows) }
  if n >= 0 {
    self.slice_rows(0, count)
  } else {
    self.slice_rows(rows - count, rows)
  }
}

///|
fn UiArray::drop_rows(self : UiArray, n : Int) -> UiArray {
  if self.rank() == 0 {
    return if n == 0 { self } else { { shape: [0], data: [] } }
  }
  let rows = self.row_count()
  let count = if n >= 0 { n.min(rows) } else { (-n).min(rows) }
  if n >= 0 {
    self.slice_rows(count, rows)
  } else {
    self.slice_rows(0, rows - count)
  }
}

///|
fn UiArray::slice_rows(
  self : UiArray,
  start_row : Int,
  end_row : Int,
) -> UiArray {
  let row_len = self.row_len()
  let start = start_row * row_len
  let end = end_row * row_len
  let data = Array::new(capacity=end - start)
  let mut i = start
  while i < end {
    data.push(self.data[i])
    i = i + 1
  }
  let shape = if self.rank() == 0 {
    if start_row == 0 && end_row == 1 {
      []
    } else {
      [0]
    }
  } else {
    let next = self.shape.copy()
    next[0] = end_row - start_row
    next
  }
  { shape, data }
}

///|
fn UiArray::transposed(self : UiArray) -> UiArray {
  if self.rank() <= 1 {
    return self
  }
  let shape = self.shape[1:].to_owned()
  shape.push(self.shape[0])
  let count = self.element_count()
  let data = Array::new(capacity=count)
  let mut flat = 0
  while flat < count {
    let indices = flat_to_indices(shape, flat)
    let old_indices = indices[shape.length() - 1:].to_owned()
    let mut i = 0
    while i < shape.length() - 1 {
      old_indices.push(indices[i])
      i = i + 1
    }
    data.push(self.data[indices_to_flat(self.shape, old_indices)])
    flat = flat + 1
  }
  { shape, data }
}

///|
fn flat_to_indices(shape : Array[Int], flat : Int) -> Array[Int] {
  if shape.is_empty() {
    return []
  }
  let indices = Array::new(capacity=shape.length())
  let mut rest = flat
  let mut i = shape.length() - 1
  while i >= 0 {
    indices.push(rest % shape[i])
    rest = rest / shape[i]
    if i == 0 {
      break
    }
    i = i - 1
  }
  indices.rev()
}

///|
fn indices_to_flat(shape : Array[Int], indices : Array[Int]) -> Int {
  let mut flat = 0
  let mut stride = 1
  let mut i = shape.length() - 1
  while i >= 0 {
    flat = flat + indices[i] * stride
    stride = stride * shape[i]
    if i == 0 {
      break
    }
    i = i - 1
  }
  flat
}

///|
fn as_nat(value : Value) -> Int raise UiuaMLError {
  let n = as_int(value)
  guard n >= 0 else { fail("Expected a non-negative integer") }
  n
}

///|
fn as_int(value : Value) -> Int raise UiuaMLError {
  match value {
    Value::Num(n) => {
      let i = n.to_int()
      guard Double::from_int(i) == n else {
        fail("Expected an integer, got \{value.render()}")
      }
      i
    }
    _ => fail("Expected a number, got \{value.render()}")
  }
}

///|
fn Value::render(self : Value) -> String {
  match self {
    Value::Num(n) => render_number(n)
    Value::Bool(b) => if b { "true" } else { "false" }
    Value::Array(array) => render_array(array)
    Value::Closure(_) => "<fun>"
    Value::Builtin(name, _, captured) =>
      if captured.is_empty() {
        "<builtin:\{name}>"
      } else {
        "<builtin:\{name}/partial>"
      }
  }
}

///|
fn render_array(array : UiArray) -> String {
  if array.rank() <= 1 {
    let body = array.data.map(item => item.render()).join(" ")
    return "[\{body}]"
  }
  let rows = Array::new(capacity=array.row_count())
  let mut row = 0
  while row < array.row_count() {
    rows.push(array.row_value(row).render())
    row = row + 1
  }
  let body = rows.join(" ")
  "[\{body}]"
}

///|
fn render_number(n : Double) -> String {
  let i = n.to_int()
  if Double::from_int(i) == n {
    i.to_string()
  } else {
    n.to_string()
  }
}
