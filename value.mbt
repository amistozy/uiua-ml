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
fn shape_is_prefix(prefix : ArrayView[Int], shape : ArrayView[Int]) -> Bool {
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
fn suffix_element_count(shape : ArrayView[Int], start : Int) -> Int {
  let mut count = 1
  let mut i = start
  while i < shape.length() {
    count = count * shape[i]
    i = i + 1
  }
  count
}

///|
fn render_shape(shape : ArrayView[Int]) -> String {
  let body = shape.map(n => n.to_string()).join(" ")
  "[\{body}]"
}

///|
fn[T] fail_shape_mismatch(
  op : StringView,
  lhs_shape : ArrayView[Int],
  rhs_shape : ArrayView[Int],
) -> T raise UiuaMLError {
  fail(
    "\{op} shape mismatch: \{render_shape(lhs_shape)} vs \{render_shape(rhs_shape)}",
  )
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
fn any_truthy(value : Value) -> Bool {
  match value {
    Value::Array(array) => array.data.any(any_truthy)
    _ => truthy(value)
  }
}

///|
fn all_truthy(value : Value) -> Bool {
  match value {
    Value::Array(array) => array.data.all(all_truthy)
    _ => truthy(value)
  }
}

///|
fn count_truthy(value : Value) -> Int {
  match value {
    Value::Array(array) =>
      array.data.fold(init=0, (count, item) => count + count_truthy(item))
    _ => if truthy(value) { 1 } else { 0 }
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
fn validate_shape(shape : ArrayView[Int], len : Int) -> Unit raise UiuaMLError {
  guard element_count_for_shape(shape) == len else {
    fail("Shape \{render_shape(shape)} does not match element count \{len}")
  }
}

///|
fn element_count_for_shape(shape : ArrayView[Int]) -> Int {
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
fn UiArray::checked_row_value(
  self : UiArray,
  row : Int,
  name : String,
) -> Value raise UiuaMLError {
  guard row >= 0 && row < self.row_count() else {
    fail("\{name} index \{row} is out of bounds for \{self.row_count()} rows")
  }
  self.row_value(row)
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
    fail_shape_mismatch("append row", self.row_shape(), other.row_shape())
  }
  let data = self.data.copy()
  for item in other.data {
    data.push(item)
  }
  let shape = [self.row_count() + other.row_count()]
  for dim in self.shape[1:] {
    shape.push(dim)
  }
  validate_shape(shape, data.length())
  { shape, data }
}

///|
fn UiArray::rotated_rows(self : UiArray, n : Int) -> UiArray {
  if self.rank() == 0 || self.row_count() == 0 {
    return self
  }
  let rows = self.row_count()
  let offset = (n % rows + rows) % rows
  if offset == 0 {
    return self
  }
  let row_len = self.row_len()
  let data = Array::new(capacity=self.element_count())
  let mut row = offset
  while row < rows {
    let start = row * row_len
    let mut i = 0
    while i < row_len {
      data.push(self.data[start + i])
      i = i + 1
    }
    row = row + 1
  }
  row = 0
  while row < offset {
    let start = row * row_len
    let mut i = 0
    while i < row_len {
      data.push(self.data[start + i])
      i = i + 1
    }
    row = row + 1
  }
  { shape: self.shape, data }
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
fn UiArray::select_rows(
  self : UiArray,
  indices : ArrayView[Int],
) -> UiArray raise UiuaMLError {
  let row_shape = self.row_shape()
  let row_len = self.row_len()
  let data = Array::new(capacity=indices.length() * row_len)
  for index in indices {
    let row = self.checked_row_value(
      normalize_row_index(index, self.row_count(), "select"),
      "select",
    )
    for item in flat_values(row) {
      data.push(item)
    }
  }
  let shape = [indices.length()]
  for dim in row_shape {
    shape.push(dim)
  }
  validate_shape(shape, data.length())
  { shape, data }
}

///|
fn UiArray::select_rows_filled(
  self : UiArray,
  indices : ArrayView[Int],
  fill : Value,
) -> UiArray raise UiuaMLError {
  let row_shape = self.row_shape()
  let row_len = self.row_len()
  let fill_row = fill_row_for_shape(row_shape, fill)
  let data = Array::new(capacity=indices.length() * row_len)
  for index in indices {
    if index < 0 || index >= self.row_count() {
      for item in fill_row {
        data.push(item)
      }
    } else {
      let row = self.row_value(index)
      for item in flat_values(row) {
        data.push(item)
      }
    }
  }
  let shape = [indices.length()]
  for dim in row_shape {
    shape.push(dim)
  }
  validate_shape(shape, data.length())
  { shape, data }
}

///|
fn UiArray::window_rows(
  self : UiArray,
  size : Int,
) -> UiArray raise UiuaMLError {
  guard self.rank() > 0 else { fail("windows cannot operate on a scalar") }
  guard size > 0 else { fail("windows size must be positive") }
  let rows = self.row_count()
  let count = if size > rows { 0 } else { rows - size + 1 }
  let row_len = self.row_len()
  let data = Array::new(capacity=count * size * row_len)
  let mut start_row = 0
  while start_row < count {
    let start = start_row * row_len
    let end = start + size * row_len
    let mut i = start
    while i < end {
      data.push(self.data[i])
      i = i + 1
    }
    start_row = start_row + 1
  }
  let shape = [count, size]
  for dim in self.row_shape() {
    shape.push(dim)
  }
  validate_shape(shape, data.length())
  { shape, data }
}

///|
fn UiArray::window_rows_filled(
  self : UiArray,
  size : Int,
  fill : Value,
) -> UiArray raise UiuaMLError {
  guard self.rank() > 0 else { fail("windows cannot operate on a scalar") }
  guard size > 0 else { fail("windows size must be positive") }
  let row_shape = self.row_shape()
  let row_len = self.row_len()
  let fill_row = fill_row_for_shape(row_shape, fill)
  let padding = size - 1
  let padded = Array::new(capacity=(self.row_count() + padding * 2) * row_len)
  let mut i = 0
  while i < padding {
    for item in fill_row {
      padded.push(item)
    }
    i = i + 1
  }
  for item in self.data {
    padded.push(item)
  }
  i = 0
  while i < padding {
    for item in fill_row {
      padded.push(item)
    }
    i = i + 1
  }
  let count = self.row_count() + padding
  let data = Array::new(capacity=count * size * row_len)
  let mut start_row = 0
  while start_row < count {
    let start = start_row * row_len
    let end = start + size * row_len
    let mut j = start
    while j < end {
      data.push(padded[j])
      j = j + 1
    }
    start_row = start_row + 1
  }
  let shape = [count, size]
  for dim in row_shape {
    shape.push(dim)
  }
  validate_shape(shape, data.length())
  { shape, data }
}

///|
fn UiArray::oriented(
  self : UiArray,
  axes : Array[Int],
) -> UiArray raise UiuaMLError {
  let rank = self.rank()
  guard axes.length() <= rank else {
    fail("Cannot orient rank \{rank} array with \{axes.length()} axes")
  }
  let perm = Array::new(capacity=rank)
  for axis in axes {
    let axis = normalize_axis(axis, rank, "orient")
    guard !perm.contains(axis) else { fail("Orient axes must be unique") }
    perm.push(axis)
  }
  let mut axis = 0
  while axis < rank {
    if !perm.contains(axis) {
      perm.push(axis)
    }
    axis = axis + 1
  }
  if rank <= 1 || perm.length() <= 1 {
    return self
  }
  let shape = Array::new(capacity=rank)
  for axis in perm {
    shape.push(self.shape[axis])
  }
  let count = self.element_count()
  let data = Array::new(capacity=count)
  let mut flat = 0
  while flat < count {
    let new_indices = flat_to_indices(shape, flat)
    let old_indices = Array::new(capacity=rank)
    let mut i = 0
    while i < rank {
      old_indices.push(0)
      i = i + 1
    }
    i = 0
    while i < rank {
      old_indices[perm[i]] = new_indices[i]
      i = i + 1
    }
    data.push(self.data[indices_to_flat(self.shape, old_indices)])
    flat = flat + 1
  }
  { shape, data }
}

///|
fn UiArray::oriented_filled(
  self : UiArray,
  axes : Array[Int],
  fill : Value,
) -> UiArray raise UiuaMLError {
  let rank = self.rank()
  let normalized = Array::new(capacity=axes.length())
  for axis in axes {
    normalized.push(normalize_axis(axis, rank, "orient"))
  }
  let duplicate_count = count_duplicate_axes(normalized)
  let perm = normalized.copy()
  let mut axis = 0
  while axis < rank {
    if !perm.contains(axis) {
      perm.push(axis)
    }
    axis = axis + 1
  }
  let shape = Array::new(capacity=rank + duplicate_count)
  let mut i = 0
  while i < normalized.length() {
    shape.push(self.shape[normalized[i]])
    i = i + 1
  }
  axis = 0
  while axis < rank {
    if !normalized.contains(axis) {
      shape.push(self.shape[axis])
    }
    axis = axis + 1
  }
  let fill_scalar = expect_fill_scalar(fill, "orient")
  let count = element_count_for_shape(shape)
  let data = Array::new(capacity=count)
  let mut flat = 0
  while flat < count {
    data.push(fill_scalar)
    flat = flat + 1
  }
  let out = UiArray::{ shape, data }
  let mut orig_flat = 0
  while orig_flat < self.element_count() {
    let orig_index = flat_to_indices(self.shape, orig_flat)
    let into_index = Array::new(capacity=out.rank())
    let mut j = 0
    while j < perm.length() {
      into_index.push(orig_index[perm[j]])
      j = j + 1
    }
    let out_flat = indices_to_flat(out.shape, into_index)
    out.data[out_flat] = self.data[orig_flat]
    orig_flat = orig_flat + 1
  }
  out
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
fn UiArray::take_rows_filled(
  self : UiArray,
  n : Int,
  fill : Value,
) -> UiArray raise UiuaMLError {
  if self.rank() == 0 {
    return if n == 0 { { shape: [0], data: [] } } else { self }
  }
  let rows = self.row_count()
  let need = n.abs()
  let row_shape = self.row_shape()
  let row_len = self.row_len()
  let fill_row = fill_row_for_shape(row_shape, fill)
  if need <= rows {
    return self.take_rows(n)
  }
  let missing = need - rows
  let data = Array::new(capacity=need * row_len)
  if n >= 0 {
    for item in self.data {
      data.push(item)
    }
    let mut i = 0
    while i < missing {
      for item in fill_row {
        data.push(item)
      }
      i = i + 1
    }
  } else {
    let mut i = 0
    while i < missing {
      for item in fill_row {
        data.push(item)
      }
      i = i + 1
    }
    for item in self.data {
      data.push(item)
    }
  }
  let shape = [need]
  for dim in row_shape {
    shape.push(dim)
  }
  validate_shape(shape, data.length())
  { shape, data }
}

///|
fn UiArray::drop_rows_filled(
  self : UiArray,
  n : Int,
  fill : Value,
) -> UiArray raise UiuaMLError {
  if self.rank() == 0 {
    return if n == 0 { self } else { { shape: [0], data: [] } }
  }
  let rows = self.row_count()
  let row_shape = self.row_shape()
  let row_len = self.row_len()
  let fill_row = fill_row_for_shape(row_shape, fill)
  let count = n.abs().min(rows)
  let kept = if n >= 0 {
    self.slice_rows(count, rows)
  } else {
    self.slice_rows(0, rows - count)
  }
  let data = Array::new(capacity=rows * row_len)
  if n >= 0 {
    for item in kept.data {
      data.push(item)
    }
    let mut i = 0
    while i < count {
      for item in fill_row {
        data.push(item)
      }
      i = i + 1
    }
  } else {
    let mut i = 0
    while i < count {
      for item in fill_row {
        data.push(item)
      }
      i = i + 1
    }
    for item in kept.data {
      data.push(item)
    }
  }
  validate_shape(self.shape, data.length())
  { shape: self.shape, data }
}

///|
fn UiArray::rotated_rows_filled(
  self : UiArray,
  n : Int,
  fill : Value,
) -> UiArray raise UiuaMLError {
  if self.rank() == 0 || self.row_count() == 0 {
    return self
  }
  let rows = self.row_count()
  let row_shape = self.row_shape()
  let row_len = self.row_len()
  let fill_row = fill_row_for_shape(row_shape, fill)
  let count = n.abs().min(rows)
  let data = Array::new(capacity=self.element_count())
  if n >= 0 {
    let start = count * row_len
    let mut i = start
    while i < self.element_count() {
      data.push(self.data[i])
      i = i + 1
    }
    let mut j = 0
    while j < count {
      for item in fill_row {
        data.push(item)
      }
      j = j + 1
    }
  } else {
    let mut j = 0
    while j < count {
      for item in fill_row {
        data.push(item)
      }
      j = j + 1
    }
    let end = self.element_count() - count * row_len
    let mut i = 0
    while i < end {
      data.push(self.data[i])
      i = i + 1
    }
  }
  validate_shape(self.shape, data.length())
  { shape: self.shape, data }
}

///|
fn flat_to_indices(shape : ArrayView[Int], flat : Int) -> Array[Int] {
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
fn indices_to_flat(shape : ArrayView[Int], indices : ArrayView[Int]) -> Int {
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
fn normalize_axis(
  axis : Int,
  rank : Int,
  op : StringView,
) -> Int raise UiuaMLError {
  let normalized = if axis >= 0 { axis } else { rank + axis }
  guard normalized >= 0 && normalized < rank else {
    fail("Cannot \{op} axis \{axis} in array of rank \{rank}")
  }
  normalized
}

///|
fn normalize_row_index(
  index : Int,
  row_count : Int,
  op : StringView,
) -> Int raise UiuaMLError {
  let normalized = if index >= 0 { index } else { row_count + index }
  guard normalized >= 0 && normalized < row_count else {
    fail("\{op} index \{index} is out of bounds for \{row_count} rows")
  }
  normalized
}

///|
fn count_duplicate_axes(axes : ArrayView[Int]) -> Int {
  let seen = Array::new()
  let mut duplicates = 0
  for axis in axes {
    if seen.contains(axis) {
      duplicates = duplicates + 1
    } else {
      seen.push(axis)
    }
  }
  duplicates
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
fn as_index_vector(
  value : Value,
  name : StringView,
) -> Array[Int] raise UiuaMLError {
  match value {
    Value::Num(_) => [as_int(value)]
    Value::Array(array) => {
      guard array.rank() <= 1 else {
        fail("\{name} expects an integer or a vector of integers")
      }
      let indices = Array::new(capacity=array.element_count())
      for item in array.data {
        indices.push(as_int(item))
      }
      indices
    }
    _ => fail("\{name} expects an integer or a vector of integers")
  }
}

///|
fn as_shaped_indices(
  value : Value,
  name : StringView,
) -> (Array[Int], Array[Int]) raise UiuaMLError {
  match value {
    Value::Num(_) => ([], [as_int(value)])
    Value::Array(array) => {
      let indices = Array::new(capacity=array.element_count())
      for item in array.data {
        indices.push(as_int(item))
      }
      (array.shape, indices)
    }
    _ => fail("\{name} expects an integer or an array of integers")
  }
}

///|
fn pick_from(
  value : Value,
  indices : ArrayView[Int],
  fill : Value?,
) -> Value raise UiuaMLError {
  if indices.is_empty() {
    return value
  }
  match value {
    Value::Array(array) => {
      let index = indices[0]
      if fill is Some(fill_value) && index < 0 {
        return fill_value_for_pick(array, indices.length() - 1, fill_value)
      }
      let normalized = if index < 0 {
        let next = array.row_count() + index
        guard next >= 0 else {
          if fill is Some(fill_value) {
            return fill_value_for_pick(array, indices.length() - 1, fill_value)
          }
          fail(
            "pick index \{index} is out of bounds for \{array.row_count()} rows",
          )
        }
        next
      } else {
        index
      }
      if normalized >= array.row_count() {
        if fill is Some(fill_value) {
          return fill_value_for_pick(array, indices.length() - 1, fill_value)
        }
        fail(
          "pick index \{index} is out of bounds for \{array.row_count()} rows",
        )
      }
      let row = array.row_value(normalized)
      pick_from(row, indices[1:], fill)
    }
    _ => fail("Cannot pick deeper into a scalar value")
  }
}

///|
fn pick_with_selector(
  value : Value,
  selector_shape : ArrayView[Int],
  indices : ArrayView[Int],
  fill : Value?,
) -> Value raise UiuaMLError {
  if selector_shape.length() <= 1 {
    return pick_from(value, indices, fill)
  }
  let value_shape = infer_shape(value)
  let index_len = selector_shape[selector_shape.length() - 1]
  guard index_len <= value_shape.length() else {
    fail(
      "Cannot pick from rank \{value_shape.length()} value with index length \{index_len}",
    )
  }
  let expected_shape = selector_shape[0:selector_shape.length() - 1].to_owned()
  for dim in value_shape[index_len:] {
    expected_shape.push(dim)
  }
  let row_count = selector_shape[0]
  let mut row_len = 1
  let mut shape_i = 1
  while shape_i < selector_shape.length() {
    row_len = row_len * selector_shape[shape_i]
    shape_i = shape_i + 1
  }
  if row_count == 0 {
    return make_array(expected_shape, [])
  }
  let picked = Array::new(capacity=row_count)
  let mut row = 0
  while row < row_count {
    let start = row * row_len
    let end = start + row_len
    picked.push(
      pick_with_selector(value, selector_shape[1:], indices[start:end], fill),
    )
    row = row + 1
  }
  let result = array_from_items(picked)
  guard infer_shape(result) == expected_shape else {
    fail("pick produced an unexpected shape")
  }
  result
}

///|
fn select_with_selector(
  array : UiArray,
  selector_shape : ArrayView[Int],
  indices : ArrayView[Int],
  fill : Value?,
) -> Value raise UiuaMLError {
  if selector_shape.is_empty() {
    return pick_from(Value::Array(array), indices, fill)
  }
  if selector_shape.length() == 1 {
    return Value::Array(
      match fill {
        Some(fill_value) => array.select_rows_filled(indices, fill_value)
        None => array.select_rows(indices)
      },
    )
  }
  let expected_shape = selector_shape.to_owned()
  for dim in array.row_shape() {
    expected_shape.push(dim)
  }
  let row_count = selector_shape[0]
  let mut row_len = 1
  let mut shape_i = 1
  while shape_i < selector_shape.length() {
    row_len = row_len * selector_shape[shape_i]
    shape_i = shape_i + 1
  }
  if row_count == 0 {
    return make_array(expected_shape, [])
  }
  let selected = Array::new(capacity=row_count)
  let mut row = 0
  while row < row_count {
    let start = row * row_len
    let end = start + row_len
    selected.push(
      select_with_selector(array, selector_shape[1:], indices[start:end], fill),
    )
    row = row + 1
  }
  let result = array_from_items(selected)
  guard infer_shape(result) == expected_shape else {
    fail("select produced an unexpected shape")
  }
  result
}

///|
fn fill_value_for_pick(
  array : UiArray,
  remaining_depth : Int,
  fill : Value,
) -> Value raise UiuaMLError {
  let target_shape = if remaining_depth + 1 >= array.rank() {
    []
  } else {
    array.shape[remaining_depth + 1:].to_owned()
  }
  fill_value_for_shape(target_shape, fill, "pick")
}

///|
fn fill_row_for_shape(
  shape : Array[Int],
  fill : Value,
) -> Array[Value] raise UiuaMLError {
  flat_values(fill_value_for_shape(shape, fill, "fill"))
}

///|
fn fill_value_for_shape(
  shape : ArrayView[Int],
  fill : Value,
  op : StringView,
) -> Value raise UiuaMLError {
  let fill_shape = infer_shape(fill)
  if fill_shape == shape.to_owned() {
    return fill
  }
  if fill_shape.is_empty() {
    if shape.is_empty() {
      return fill
    }
    let count = element_count_for_shape(shape)
    let data = Array::new(capacity=count)
    let mut i = 0
    while i < count {
      data.push(fill)
      i = i + 1
    }
    return make_array(shape.to_owned(), data)
  }
  fail(
    "\{op} fill shape mismatch: expected \{render_shape(shape)}, got \{render_shape(fill_shape)}",
  )
}

///|
fn expect_fill_scalar(fill : Value, op : StringView) -> Value raise UiuaMLError {
  guard infer_shape(fill).is_empty() else {
    fail(
      "\{op} expects a scalar fill value, got \{render_shape(infer_shape(fill))}",
    )
  }
  fill
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
