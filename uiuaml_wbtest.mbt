///|
test "infer_shape for scalar and nested arrays" {
  assert_eq(infer_shape(Value::Num(1.0)), [])
  assert_eq(
    infer_shape(
      Value::Array([
        Value::Array([Value::Num(1.0), Value::Num(2.0)]),
        Value::Array([Value::Num(3.0), Value::Num(4.0)]),
      ]),
    ),
    [2, 2],
  )
}

///|
test "flatten keeps row major order" {
  let flattened = flatten(
    Value::Array([
      Value::Array([Value::Num(1.0), Value::Num(2.0)]),
      Value::Array([Value::Num(3.0)]),
    ]),
  )
  assert_eq(flattened.map(v => v.render()), ["1", "2", "3"])
}
