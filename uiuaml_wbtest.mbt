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
