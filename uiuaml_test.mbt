///|
test "pervasive arithmetic" {
  assert_eq(try? interpret("[1, 2, 3] + 10"), Ok("[11 12 13]"))
  assert_eq(try? interpret("[1, 2, 3] + [10, 20, 30]"), Ok("[11 22 33]"))
}

///|
test "functions and lets" {
  assert_eq(try? interpret("let inc = fun x -> x + 1 in inc 41"), Ok("42"))
  assert_eq(
    try? interpret("let add = fun x -> fun y -> x + y in add 3 4"),
    Ok("7"),
  )
}

///|
test "arrays inspired by uiua" {
  assert_eq(try? interpret("range 5"), Ok("[0 1 2 3 4]"))
  assert_eq(try? interpret("sum [1, 2, 3, 4]"), Ok("10"))
  assert_eq(try? interpret("shape [[1, 2], [3, 4]]"), Ok("[2 2]"))
  assert_eq(
    try? interpret("reshape [2, 3] [1, 2, 3, 4]"),
    Ok("[[1 2 3] [4 1 2]]"),
  )
}

///|
test "conditionals and comparisons" {
  assert_eq(try? interpret("if sum [1, 1, 1] == 3 then 42 else 0"), Ok("42"))
  assert_eq(try? interpret("[1, 2, 3] > 1"), Ok("[false true true]"))
}

///|
test "comments are ignored" {
  let program =
    #|let xs = range 4 # array source
    #|in sum xs
  assert_eq(try? interpret(program), Ok("6"))
}
