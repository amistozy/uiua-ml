///|
test "pervasive arithmetic" {
  assert_eq(try? interpret("[1, 2, 3] + 10"), Ok("[11 12 13]"))
  assert_eq(try? interpret("[1, 2, 3] + [10, 20, 30]"), Ok("[11 22 33]"))
  assert_eq(
    try? interpret("[10, 20] + [[3, 4, 5], [6, 7, 8]]"),
    Ok("[[13 14 15] [26 27 28]]"),
  )
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
  assert_eq(try? interpret("map (fun x -> x + 1) [1, 2, 3]"), Ok("[2 3 4]"))
  assert_eq(
    try? interpret("each (fun row -> sum row) [[1, 2], [3, 4], [5, 6]]"),
    Ok("[3 7 11]"),
  )
  assert_eq(
    try? interpret("filter (fun x -> x > 2) [1, 2, 3, 4, 5]"),
    Ok("[3 4 5]"),
  )
  assert_eq(
    try? interpret("filter (fun row -> sum row > 6) [[1, 2], [3, 4], [5, 6]]"),
    Ok("[[3 4] [5 6]]"),
  )
  assert_eq(
    try? interpret("filter (fun row -> sum row > 100) [[1, 2], [3, 4], [5, 6]]"),
    Ok("[]"),
  )
  assert_eq(
    try? interpret("zip (fun x -> fun y -> x + y) [1, 2, 3] [10, 20, 30]"),
    Ok("[11 22 33]"),
  )
  assert_eq(
    try? interpret("zip (fun x -> fun y -> x + y) [1, 2, 3] 10"),
    Ok("[11 12 13]"),
  )
  assert_eq(
    try? interpret(
      "zip (fun row -> fun bias -> row + bias) [[1, 2], [3, 4], [5, 6]] [[10, 20]]",
    ),
    Ok("[[11 22] [13 24] [15 26]]"),
  )
  assert_eq(
    try? interpret("reduce (fun acc -> fun x -> acc + x) 0 [1, 2, 3, 4]"),
    Ok("10"),
  )
  assert_eq(
    try? interpret("scan (fun acc -> fun x -> acc + x) 0 [1, 2, 3, 4]"),
    Ok("[1 3 6 10]"),
  )
  assert_eq(
    try? interpret(
      "reduce (fun acc -> fun row -> acc + sum row) 0 [[1, 2], [3, 4], [5, 6]]",
    ),
    Ok("21"),
  )
  assert_eq(
    try? interpret(
      "scan (fun acc -> fun row -> acc + row) [0, 0] [[1, 2], [3, 4], [5, 6]]",
    ),
    Ok("[[1 2] [4 6] [9 12]]"),
  )
  assert_eq(try? interpret("scan (fun acc -> fun x -> acc + x) 0 []"), Ok("[]"))
  assert_eq(try? interpret("sum [1, 2, 3, 4]"), Ok("10"))
  assert_eq(try? interpret("any [0, 0, 1, 0]"), Ok("true"))
  assert_eq(try? interpret("any []"), Ok("false"))
  assert_eq(try? interpret("all [1, 2, 3]"), Ok("true"))
  assert_eq(try? interpret("all [1, 0, 3]"), Ok("false"))
  assert_eq(try? interpret("all []"), Ok("true"))
  assert_eq(try? interpret("any [[0, 0], [0, 2]]"), Ok("true"))
  assert_eq(try? interpret("count [0, 1, 0, 2, 3]"), Ok("3"))
  assert_eq(try? interpret("count []"), Ok("0"))
  assert_eq(try? interpret("count [[0, 1], [2, 0], [3, 4]]"), Ok("4"))
  assert_eq(try? interpret("where [0, 1, 0, 1, 1, 0, 0]"), Ok("[1 3 4]"))
  assert_eq(try? interpret("shape [[1, 2], [3, 4]]"), Ok("[2 2]"))
  assert_eq(try? interpret("rank [[1, 2], [3, 4]]"), Ok("2"))
  assert_eq(try? interpret("first [[1, 2], [3, 4]]"), Ok("[1 2]"))
  assert_eq(try? interpret("last [[1, 2], [3, 4]]"), Ok("[3 4]"))
  assert_eq(
    try? interpret("reverse [[1, 2], [3, 4], [5, 6]]"),
    Ok("[[5 6] [3 4] [1 2]]"),
  )
  assert_eq(try? interpret("deshape [[1, 2], [3, 4]]"), Ok("[1 2 3 4]"))
  assert_eq(try? interpret("take 3 [1, 2, 3, 4, 5]"), Ok("[1 2 3]"))
  assert_eq(try? interpret("take -2 [1, 2, 3, 4, 5]"), Ok("[4 5]"))
  assert_eq(try? interpret("drop 3 [1, 2, 3, 4, 5]"), Ok("[4 5]"))
  assert_eq(try? interpret("drop -2 [1, 2, 3, 4, 5]"), Ok("[1 2 3]"))
  assert_eq(try? interpret("pick 2 [3, 8, 4, 1]"), Ok("4"))
  assert_eq(try? interpret("pick [1, 1] [[1, 2, 3], [4, 5, 6]]"), Ok("5"))
  assert_eq(
    try? interpret("select [0, 2, 1, 1] [[1, 2], [3, 4], [5, 6]]"),
    Ok("[[1 2] [5 6] [3 4] [3 4]]"),
  )
  assert_eq(
    try? interpret("keep [0, 1, 0, 1, 1, 0, 0] [2, 8, 3, 9, 1, 7, 2]"),
    Ok("[8 9 1]"),
  )
  assert_eq(
    try? interpret("keep ([1, 0, 1] == 1) [[1, 2], [3, 4], [5, 6]]"),
    Ok("[[1 2] [5 6]]"),
  )
  assert_eq(
    try? interpret("select (where [0, 1, 0, 1]) [2, 8, 3, 9]"),
    Ok("[8 9]"),
  )
  assert_eq(
    try? interpret("windows 3 [1, 2, 3, 4, 5]"),
    Ok("[[1 2 3] [2 3 4] [3 4 5]]"),
  )
  assert_eq(
    try? interpret("windows 2 [[1, 2], [3, 4], [5, 6]]"),
    Ok("[[[1 2] [3 4]] [[3 4] [5 6]]]"),
  )
  assert_eq(
    try? interpret("orient [1, 0] [[1, 2, 3], [4, 5, 6]]"),
    Ok("[[1 4] [2 5] [3 6]]"),
  )
  assert_eq(
    try? interpret("orient [2, 0] [[[1, 2], [3, 4]], [[5, 6], [7, 8]]]"),
    Ok("[[[1 3] [5 7]] [[2 4] [6 8]]]"),
  )
  assert_eq(try? interpret("rotate 2 [1, 2, 3, 4, 5]"), Ok("[3 4 5 1 2]"))
  assert_eq(
    try? interpret("rotate -1 [[1, 2], [3, 4], [5, 6]]"),
    Ok("[[5 6] [1 2] [3 4]]"),
  )
  assert_eq(
    try? interpret("transpose [[1, 2, 3], [4, 5, 6]]"),
    Ok("[[1 4] [2 5] [3 6]]"),
  )
  assert_eq(
    try? interpret("append [[1, 2]] [[3, 4], [5, 6]]"),
    Ok("[[1 2] [3 4] [5 6]]"),
  )
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
test "fill semantics for structural operations" {
  assert_eq(try? interpret("fill 0 in take 5 [1, 2, 3]"), Ok("[1 2 3 0 0]"))
  assert_eq(
    try? interpret("fill [9, 9] in take 4 [[1, 2], [3, 4]]"),
    Ok("[[1 2] [3 4] [9 9] [9 9]]"),
  )
  assert_eq(try? interpret("fill 0 in drop 2 [1, 2, 3, 4]"), Ok("[3 4 0 0]"))
  assert_eq(
    try? interpret("fill 0 in rotate 2 [1, 2, 3, 4, 5]"),
    Ok("[3 4 5 0 0]"),
  )
  assert_eq(try? interpret("fill 0 in pick 9 [3, 8, 4, 1]"), Ok("0"))
  assert_eq(
    try? interpret("fill [9, 9] in select [0, 9, -1] [[1, 2], [3, 4]]"),
    Ok("[[1 2] [9 9] [9 9]]"),
  )
  assert_eq(
    try? interpret("fill 0 in reshape [2, 3] [1, 2, 3, 4]"),
    Ok("[[1 2 3] [4 0 0]]"),
  )
  assert_eq(
    try? interpret("fill 0 in windows 3 [1, 2, 3]"),
    Ok("[[0 0 1] [0 1 2] [1 2 3] [2 3 0] [3 0 0]]"),
  )
}

///|
test "shape and index errors are more explicit" {
  let shape_error = try interpret("[1, 2] + [1, 2, 3]") catch {
    err => err.to_string()
  } noraise {
    value => "unexpected ok: \{value}"
  }
  assert_eq(shape_error, "pervasive operation shape mismatch: [2] vs [3]")
  let index_error = try interpret("pick 9 [1, 2]") catch {
    err => err.to_string()
  } noraise {
    value => "unexpected ok: \{value}"
  }
  assert_eq(index_error, "pick index 9 is out of bounds for 2 rows")
}

///|
test "comments are ignored" {
  let program =
    #|let xs = range 4 # array source
    #|in sum xs
  assert_eq(try? interpret(program), Ok("6"))
}
