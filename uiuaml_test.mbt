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
  assert_eq(try? interpret("(fun x y -> x + y) 3 4"), Ok("7"))
  assert_eq(try? interpret("let add x y = x + y in add 3 4"), Ok("7"))
  assert_eq(try? interpret("let bias x y z = x + y + z in bias 1 2 3"), Ok("6"))
}

///|
test "arrays inspired by uiua" {
  assert_eq(try? interpret("range 5"), Ok("[0 1 2 3 4]"))
  assert_eq(try? interpret("range -5"), Ok("[-1 -2 -3 -4 -5]"))
  assert_eq(
    try? interpret("range [3, 3]"),
    Ok("[[[0 0] [0 1] [0 2]] [[1 0] [1 1] [1 2]] [[2 0] [2 1] [2 2]]]"),
  )
  assert_eq(
    try? interpret("range [2, 3]"),
    Ok("[[[0 0] [0 1] [0 2]] [[1 0] [1 1] [1 2]]]"),
  )
  assert_eq(
    try? interpret("range [-2, 3]"),
    Ok("[[[-1 0] [-1 1] [-1 2]] [[-2 0] [-2 1] [-2 2]]]"),
  )
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
  assert_eq(
    try? interpret("take [2, 3] (reshape [3, 4] (range 12))"),
    Ok("[[0 1 2] [4 5 6]]"),
  )
  assert_eq(
    try? interpret("take [-2, -2] (reshape [3, 3] (range 9))"),
    Ok("[[4 5] [7 8]]"),
  )
  assert_eq(try? interpret("drop 3 [1, 2, 3, 4, 5]"), Ok("[4 5]"))
  assert_eq(try? interpret("drop -2 [1, 2, 3, 4, 5]"), Ok("[1 2 3]"))
  assert_eq(
    try? interpret("drop [1, 1] (reshape [2, 2] (range 4))"),
    Ok("[[3]]"),
  )
  assert_eq(
    try? interpret("drop [-2, -2] (reshape [3, 3] (range 9))"),
    Ok("[[0]]"),
  )
  assert_eq(try? interpret("pick 2 [3, 8, 4, 1]"), Ok("4"))
  assert_eq(try? interpret("pick [1, 1] [[1, 2, 3], [4, 5, 6]]"), Ok("5"))
  assert_eq(
    try? interpret("pick [[1, 2], [0, 1]] [[1, 2, 3], [4, 5, 6]]"),
    Ok("[6 2]"),
  )
  assert_eq(
    try? interpret("select [0, 2, 1, 1] [[1, 2], [3, 4], [5, 6]]"),
    Ok("[[1 2] [5 6] [3 4] [3 4]]"),
  )
  assert_eq(
    try? interpret("select [[0, 1], [1, 2], [2, 0]] [2, 3, 5, 7]"),
    Ok("[[2 3] [3 5] [5 2]]"),
  )
  assert_eq(
    try? interpret("select [[0, 1], [1, 2], [2, 0]] [[1, 2], [3, 4], [5, 6]]"),
    Ok("[[[1 2] [3 4]] [[3 4] [5 6]] [[5 6] [1 2]]]"),
  )
  assert_eq(
    try? interpret("keep [0, 1, 0, 1, 1, 0, 0] [2, 8, 3, 9, 1, 7, 2]"),
    Ok("[8 9 1]"),
  )
  assert_eq(try? interpret("keep 3 [1, 2, 3]"), Ok("[1 1 1 2 2 2 3 3 3]"))
  assert_eq(try? interpret("keep [2, 1, 1] [1, 2, 3]"), Ok("[1 1 2 3]"))
  assert_eq(try? interpret("keep [1, 2, 1] [1, 2, 3]"), Ok("[1 2 2 3]"))
  assert_eq(try? interpret("keep [1, 1, 2] [1, 2, 3]"), Ok("[1 2 3 3]"))
  assert_eq(try? interpret("keep [3, 2, 1] [1, 2, 3]"), Ok("[1 1 1 2 2 3]"))
  assert_eq(try? interpret("keep [1, 0, 1] (range 10)"), Ok("[0 2 3 5 6 8 9]"))
  assert_eq(
    try? interpret("fill [1, 2, 0] in keep [0, 4] (range 10)"),
    Ok("[1 1 1 1 2 3 3 5 6 6 8 9 9]"),
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
  assert_eq(
    try? interpret("orient [-1] [[1, 2, 3], [4, 5, 6]]"),
    Ok("[[1 4] [2 5] [3 6]]"),
  )
  assert_eq(try? interpret("rotate 2 [1, 2, 3, 4, 5]"), Ok("[3 4 5 1 2]"))
  assert_eq(
    try? interpret("rotate -1 [[1, 2], [3, 4], [5, 6]]"),
    Ok("[[5 6] [1 2] [3 4]]"),
  )
  assert_eq(
    try? interpret("rotate [1, 2] (reshape [4, 5] (range 20))"),
    Ok("[[7 8 9 5 6] [12 13 14 10 11] [17 18 19 15 16] [2 3 4 0 1]]"),
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
  assert_eq(try? interpret("[1, 2, 3,]"), Ok("[1 2 3]"))
  assert_eq(try? interpret("let pair x y = [x, y,] in pair 3 4"), Ok("[3 4]"))
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
    try? interpret("fill 0 in pick [[1, 2], [9, 9]] [[1, 2, 3], [4, 5, 6]]"),
    Ok("[6 0]"),
  )
  assert_eq(
    try? interpret("fill [9, 9] in select [[0, 1], [9, -1]] [[1, 2], [3, 4]]"),
    Ok("[[[1 2] [3 4]] [[9 9] [9 9]]]"),
  )
  assert_eq(
    try? interpret("fill 0 in reshape [2, 3] [1, 2, 3, 4]"),
    Ok("[[1 2 3] [4 0 0]]"),
  )
  assert_eq(
    try? interpret("fill 0 in windows 3 [1, 2, 3]"),
    Ok("[[0 0 1] [0 1 2] [1 2 3] [2 3 0] [3 0 0]]"),
  )
  assert_eq(
    try? interpret("fill 0 in orient [0, 0] [1, 2, 3, 4]"),
    Ok("[[1 0 0 0] [0 2 0 0] [0 0 3 0] [0 0 0 4]]"),
  )
  assert_eq(
    try? interpret("fill 0 in orient [0, 1, 1] [[1, 2], [3, 4]]"),
    Ok("[[[1 0] [0 2]] [[3 0] [0 4]]]"),
  )
  assert_eq(
    try? interpret("fill 0 in take [3, 3] (reshape [2, 2] (range 4))"),
    Ok("[[0 1 0] [2 3 0] [0 0 0]]"),
  )
  assert_eq(
    try? interpret("fill 0 in rotate [1, 2] (reshape [4, 5] (range 20))"),
    Ok("[[7 8 9 0 0] [12 13 14 0 0] [17 18 19 0 0] [0 0 0 0 0]]"),
  )
}

///|
test "shape and index errors are more explicit" {
  let shape_error = try interpret("[1, 2] + [1, 2, 3]") catch {
    err => err.to_string()
  } noraise {
    value => "unexpected ok: \{value}"
  }
  assert_eq(
    shape_error,
    (
      #|pervasive operation shape mismatch: [2] vs [3]
      #|  at 1:1
      #|1 | [1, 2] + [1, 2, 3]
      #|    ^^^^^^^^^^^^^^^^^^
    ),
  )
  let index_error = try interpret("pick 9 [1, 2]") catch {
    err => err.to_string()
  } noraise {
    value => "unexpected ok: \{value}"
  }
  assert_eq(
    index_error,
    (
      #|pick index 9 is out of bounds for 2 rows
      #|  at 1:1
      #|1 | pick 9 [1, 2]
      #|    ^^^^^^^^^^^^^
    ),
  )
}

///|
test "parse errors also report source locations" {
  let parse_error = try interpret("if true then 1") catch {
    err => err.to_string()
  } noraise {
    value => "unexpected ok: \{value}"
  }
  assert_eq(
    parse_error,
    (
      #|Expected else, got end of input
      #|  at 1:15
      #|1 | if true then 1
      #|                  ^
    ),
  )
}

///|
test "comments are ignored" {
  let program =
    #|let xs = range 4 # array source
    #|in sum xs
  assert_eq(try? interpret(program), Ok("6"))
}
