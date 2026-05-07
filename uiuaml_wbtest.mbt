///|
test "infer_shape for scalar and nested arrays" {
  assert_eq(infer_shape(Value::Num(1.0)), [])
  assert_eq(
    infer_shape(
      make_array([2, 2], [
        Value::Num(1.0),
        Value::Num(2.0),
        Value::Num(3.0),
        Value::Num(4.0),
      ]),
    ),
    [2, 2],
  )
}

///|
test "flat_values keeps row major order" {
  let flattened = flat_values(
    make_array([2, 2], [
      Value::Num(1.0),
      Value::Num(2.0),
      Value::Num(3.0),
      Value::Num(4.0),
    ]),
  )
  assert_eq(flattened.map(v => v.render()), ["1", "2", "3", "4"])
}

///|
test "array literal builder computes rectangular shape" {
  let built = array_from_items([
    make_array([2], [Value::Num(1.0), Value::Num(2.0)]),
    make_array([2], [Value::Num(3.0), Value::Num(4.0)]),
  ])
  assert_eq(built.render(), "[[1 2] [3 4]]")
}

///|
test "transpose rotates the leading axis to the end" {
  let array = make_array([2, 3], [
    Value::Num(1.0),
    Value::Num(2.0),
    Value::Num(3.0),
    Value::Num(4.0),
    Value::Num(5.0),
    Value::Num(6.0),
  ])
  guard array is Value::Array(arr) else { panic() }
  let transposed = arr.transposed()
  assert_eq(transposed.shape, [3, 2])
  assert_eq(Value::Array(transposed).render(), "[[1 4] [2 5] [3 6]]")
}

///|
test "pick and select use row-major indexing" {
  let array = make_array([2, 3], [
    Value::Num(1.0),
    Value::Num(2.0),
    Value::Num(3.0),
    Value::Num(4.0),
    Value::Num(5.0),
    Value::Num(6.0),
  ])
  assert_eq(pick_from(array, [1, 2]).render(), "6")
  guard array is Value::Array(arr) else { panic() }
  let selected = arr.select_rows([1, 0, 1])
  assert_eq(Value::Array(selected).render(), "[[4 5 6] [1 2 3] [4 5 6]]")
}

///|
test "rotate shifts rows forward along the leading axis" {
  let array = make_array([3, 2], [
    Value::Num(1.0),
    Value::Num(2.0),
    Value::Num(3.0),
    Value::Num(4.0),
    Value::Num(5.0),
    Value::Num(6.0),
  ])
  guard array is Value::Array(arr) else { panic() }
  assert_eq(Value::Array(arr.rotated_rows(1)).render(), "[[3 4] [5 6] [1 2]]")
  assert_eq(Value::Array(arr.rotated_rows(-1)).render(), "[[5 6] [1 2] [3 4]]")
}

///|
test "where returns coordinates for multidimensional masks" {
  let mask = make_array([2, 3], [
    Value::Bool(false),
    Value::Bool(true),
    Value::Bool(false),
    Value::Bool(true),
    Value::Bool(false),
    Value::Bool(true),
  ])
  let result = builtin_where(mask)
  assert_eq(result.render(), "[[0 1] [1 0] [1 2]]")
}

///|
test "windows creates overlapping leading-axis slices" {
  let array = make_array([4, 2], [
    Value::Num(1.0),
    Value::Num(2.0),
    Value::Num(3.0),
    Value::Num(4.0),
    Value::Num(5.0),
    Value::Num(6.0),
    Value::Num(7.0),
    Value::Num(8.0),
  ])
  guard array is Value::Array(arr) else { panic() }
  let windows = arr.window_rows(3)
  assert_eq(windows.shape, [2, 3, 2])
  assert_eq(
    Value::Array(windows).render(),
    "[[[1 2] [3 4] [5 6]] [[3 4] [5 6] [7 8]]]",
  )
}

///|
test "orient reorders axes and appends unspecified ones" {
  let array = make_array([2, 2, 2], [
    Value::Num(1.0),
    Value::Num(2.0),
    Value::Num(3.0),
    Value::Num(4.0),
    Value::Num(5.0),
    Value::Num(6.0),
    Value::Num(7.0),
    Value::Num(8.0),
  ])
  guard array is Value::Array(arr) else { panic() }
  let oriented = arr.oriented([2, 0])
  assert_eq(oriented.shape, [2, 2, 2])
  assert_eq(Value::Array(oriented).render(), "[[[1 3] [5 7]] [[2 4] [6 8]]]")
}
