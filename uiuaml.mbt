///|
pub suberror UiuaMLError {
  UiuaMLError(String)
} derive(Eq, Debug)

///|
pub impl Show for UiuaMLError with output(self, logger) {
  match self {
    UiuaMLError(message) => logger.write_string(message)
  }
}

///|
pub fn interpret(source : StringView) -> String raise UiuaMLError {
  let parser = Parser::{ tokens: tokenize(source), pos: 0 }
  let expr = parser.parse_expr()
  ignore(parser.expect(TokenKind::Eof))
  eval(expr, default_env()).render()
}

///|
fn[T] fail(message : String) -> T raise UiuaMLError {
  raise UiuaMLError(message)
}

///|
priv enum TokenKind {
  Number
  Ident
  True
  False
  Let
  In
  Fun
  If
  Then
  Else
  LParen
  RParen
  LBracket
  RBracket
  Comma
  Arrow
  Equal
  EqualEqual
  BangEqual
  Plus
  Minus
  Star
  Slash
  Less
  LessEqual
  Greater
  GreaterEqual
  Eof
} derive(Eq)

///|
priv struct Token {
  kind : TokenKind
  lexeme : String
}

///|
fn token(kind : TokenKind, lexeme : String) -> Token {
  { kind, lexeme }
}

///|
fn tokenize(source : StringView) -> Array[Token] raise UiuaMLError {
  let tokens = Array::new()
  let len = source.length()
  let mut i = 0
  while i < len {
    let ch = source.unsafe_get(i).unsafe_to_char()
    if ch.is_whitespace() {
      i = i + 1
    } else if ch == '#' {
      i = i + 1
      while i < len && source.unsafe_get(i).unsafe_to_char() != '\n' {
        i = i + 1
      }
    } else if ch.is_digit(10) {
      let start = i
      i = i + 1
      while i < len && source.unsafe_get(i).unsafe_to_char().is_digit(10) {
        i = i + 1
      }
      if i < len && source.unsafe_get(i).unsafe_to_char() == '.' {
        i = i + 1
        while i < len && source.unsafe_get(i).unsafe_to_char().is_digit(10) {
          i = i + 1
        }
      }
      tokens.push(token(TokenKind::Number, source[start:i].to_owned()))
    } else if is_ident_start(ch) {
      let start = i
      i = i + 1
      while i < len && is_ident_continue(source.unsafe_get(i).unsafe_to_char()) {
        i = i + 1
      }
      let lexeme = source[start:i].to_owned()
      tokens.push(token(keyword_or_ident(lexeme), lexeme))
    } else {
      if i + 1 < len {
        let pair = source[i:i + 2]
        if pair == "->" {
          tokens.push(token(TokenKind::Arrow, "->"))
          i = i + 2
          continue
        }
        if pair == "==" {
          tokens.push(token(TokenKind::EqualEqual, "=="))
          i = i + 2
          continue
        }
        if pair == "!=" {
          tokens.push(token(TokenKind::BangEqual, "!="))
          i = i + 2
          continue
        }
        if pair == "<=" {
          tokens.push(token(TokenKind::LessEqual, "<="))
          i = i + 2
          continue
        }
        if pair == ">=" {
          tokens.push(token(TokenKind::GreaterEqual, ">="))
          i = i + 2
          continue
        }
      }
      match ch {
        '(' => tokens.push(token(TokenKind::LParen, "("))
        ')' => tokens.push(token(TokenKind::RParen, ")"))
        '[' => tokens.push(token(TokenKind::LBracket, "["))
        ']' => tokens.push(token(TokenKind::RBracket, "]"))
        ',' => tokens.push(token(TokenKind::Comma, ","))
        '=' => tokens.push(token(TokenKind::Equal, "="))
        '+' => tokens.push(token(TokenKind::Plus, "+"))
        '-' => tokens.push(token(TokenKind::Minus, "-"))
        '*' => tokens.push(token(TokenKind::Star, "*"))
        '/' => tokens.push(token(TokenKind::Slash, "/"))
        '<' => tokens.push(token(TokenKind::Less, "<"))
        '>' => tokens.push(token(TokenKind::Greater, ">"))
        _ => fail("Unexpected character: \{ch}")
      }
      i = i + 1
    }
  }
  tokens.push(token(TokenKind::Eof, ""))
  tokens
}

///|
fn is_ident_start(ch : Char) -> Bool {
  ch == '_' || ch.is_ascii_alphabetic()
}

///|
fn is_ident_continue(ch : Char) -> Bool {
  is_ident_start(ch) || ch.is_digit(10)
}

///|
fn keyword_or_ident(lexeme : String) -> TokenKind {
  match lexeme {
    "let" => TokenKind::Let
    "in" => TokenKind::In
    "fun" => TokenKind::Fun
    "if" => TokenKind::If
    "then" => TokenKind::Then
    "else" => TokenKind::Else
    "true" => TokenKind::True
    "false" => TokenKind::False
    _ => TokenKind::Ident
  }
}

///|
priv enum Expr {
  Number(Double)
  Bool(Bool)
  Var(String)
  ArrayLit(Array[Expr])
  Let(String, Expr, Expr)
  If(Expr, Expr, Expr)
  Fun(String, Expr)
  Call(Expr, Expr)
  Unary(String, Expr)
  Binary(String, Expr, Expr)
}

///|
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int
}

///|
fn Parser::current(self : Parser) -> Token {
  self.tokens[self.pos]
}

///|
fn Parser::advance(self : Parser) -> Token {
  let tok = self.current()
  self.pos = self.pos + 1
  tok
}

///|
fn Parser::at(self : Parser, kind : TokenKind) -> Bool {
  self.current().kind == kind
}

///|
fn Parser::eat(self : Parser, kind : TokenKind) -> Bool {
  if self.at(kind) {
    ignore(self.advance())
    true
  } else {
    false
  }
}

///|
fn Parser::expect(self : Parser, kind : TokenKind) -> Token raise UiuaMLError {
  if self.at(kind) {
    self.advance()
  } else {
    fail(
      "Expected \{token_kind_name(kind)}, got \{token_kind_name(self.current().kind)}",
    )
  }
}

///|
fn token_kind_name(kind : TokenKind) -> String {
  match kind {
    Number => "number"
    Ident => "identifier"
    True => "true"
    False => "false"
    Let => "let"
    In => "in"
    Fun => "fun"
    If => "if"
    Then => "then"
    Else => "else"
    LParen => "("
    RParen => ")"
    LBracket => "["
    RBracket => "]"
    Comma => ","
    Arrow => "->"
    Equal => "="
    EqualEqual => "=="
    BangEqual => "!="
    Plus => "+"
    Minus => "-"
    Star => "*"
    Slash => "/"
    Less => "<"
    LessEqual => "<="
    Greater => ">"
    GreaterEqual => ">="
    Eof => "end of input"
  }
}

///|
fn Parser::parse_expr(self : Parser) -> Expr raise UiuaMLError {
  if self.eat(TokenKind::Let) {
    return self.parse_let()
  }
  if self.eat(TokenKind::If) {
    return self.parse_if()
  }
  if self.eat(TokenKind::Fun) {
    return self.parse_fun()
  }
  self.parse_comparison()
}

///|
fn Parser::parse_let(self : Parser) -> Expr raise UiuaMLError {
  let name = self.expect(TokenKind::Ident).lexeme
  ignore(self.expect(TokenKind::Equal))
  let value = self.parse_expr()
  ignore(self.expect(TokenKind::In))
  let body = self.parse_expr()
  Expr::Let(name, value, body)
}

///|
fn Parser::parse_if(self : Parser) -> Expr raise UiuaMLError {
  let cond = self.parse_expr()
  ignore(self.expect(TokenKind::Then))
  let on_true = self.parse_expr()
  ignore(self.expect(TokenKind::Else))
  let on_false = self.parse_expr()
  Expr::If(cond, on_true, on_false)
}

///|
fn Parser::parse_fun(self : Parser) -> Expr raise UiuaMLError {
  let param = self.expect(TokenKind::Ident).lexeme
  ignore(self.expect(TokenKind::Arrow))
  Expr::Fun(param, self.parse_expr())
}

///|
fn Parser::parse_comparison(self : Parser) -> Expr raise UiuaMLError {
  let mut expr = self.parse_additive()
  while true {
    let op = match self.current().kind {
      TokenKind::EqualEqual => Some("==")
      TokenKind::BangEqual => Some("!=")
      TokenKind::Less => Some("<")
      TokenKind::LessEqual => Some("<=")
      TokenKind::Greater => Some(">")
      TokenKind::GreaterEqual => Some(">=")
      _ => None
    }
    guard op is Some(op) else { break }
    ignore(self.advance())
    expr = Expr::Binary(op, expr, self.parse_additive())
  }
  expr
}

///|
fn Parser::parse_additive(self : Parser) -> Expr raise UiuaMLError {
  let mut expr = self.parse_multiplicative()
  while true {
    let op = match self.current().kind {
      TokenKind::Plus => Some("+")
      TokenKind::Minus => Some("-")
      _ => None
    }
    guard op is Some(op) else { break }
    ignore(self.advance())
    expr = Expr::Binary(op, expr, self.parse_multiplicative())
  }
  expr
}

///|
fn Parser::parse_multiplicative(self : Parser) -> Expr raise UiuaMLError {
  let mut expr = self.parse_application()
  while true {
    let op = match self.current().kind {
      TokenKind::Star => Some("*")
      TokenKind::Slash => Some("/")
      _ => None
    }
    guard op is Some(op) else { break }
    ignore(self.advance())
    expr = Expr::Binary(op, expr, self.parse_application())
  }
  expr
}

///|
fn Parser::parse_application(self : Parser) -> Expr raise UiuaMLError {
  let mut expr = self.parse_unary()
  while starts_expr(self.current().kind) {
    expr = Expr::Call(expr, self.parse_unary())
  }
  expr
}

///|
fn starts_expr(kind : TokenKind) -> Bool {
  match kind {
    Number | Ident | True | False | LParen | LBracket | If | Fun | Let => true
    _ => false
  }
}

///|
fn Parser::parse_unary(self : Parser) -> Expr raise UiuaMLError {
  if self.eat(TokenKind::Minus) {
    Expr::Unary("-", self.parse_unary())
  } else {
    self.parse_primary()
  }
}

///|
fn Parser::parse_primary(self : Parser) -> Expr raise UiuaMLError {
  match self.current().kind {
    TokenKind::Number => {
      let value = @string.parse_double(self.advance().lexeme[:]) catch {
        _ => fail("Invalid number literal")
      }
      Expr::Number(value)
    }
    TokenKind::True => {
      ignore(self.advance())
      Expr::Bool(true)
    }
    TokenKind::False => {
      ignore(self.advance())
      Expr::Bool(false)
    }
    TokenKind::Ident => Expr::Var(self.advance().lexeme)
    TokenKind::LParen => {
      ignore(self.advance())
      let expr = self.parse_expr()
      ignore(self.expect(TokenKind::RParen))
      expr
    }
    TokenKind::LBracket => self.parse_array()
    _ => fail("Unexpected token: \{token_kind_name(self.current().kind)}")
  }
}

///|
fn Parser::parse_array(self : Parser) -> Expr raise UiuaMLError {
  ignore(self.expect(TokenKind::LBracket))
  let items = Array::new()
  if !self.at(TokenKind::RBracket) {
    items.push(self.parse_expr())
    while self.eat(TokenKind::Comma) {
      items.push(self.parse_expr())
    }
  }
  ignore(self.expect(TokenKind::RBracket))
  Expr::ArrayLit(items)
}

///|
type Env = @hashmap.HashMap[String, Value]

///|
priv struct Closure {
  param : String
  body : Expr
  env : Env
}

///|
priv enum Value {
  Num(Double)
  Bool(Bool)
  Array(Array[Value])
  Closure(Closure)
  Builtin(String, Int, Array[Value])
}

///|
fn default_env() -> Env {
  let env : Env = @hashmap.new()
  bind_builtin(env, "range", 1)
  bind_builtin(env, "iota", 1)
  bind_builtin(env, "shape", 1)
  bind_builtin(env, "sum", 1)
  bind_builtin(env, "first", 1)
  bind_builtin(env, "reverse", 1)
  bind_builtin(env, "len", 1)
  bind_builtin(env, "reshape", 2)
  bind_builtin(env, "append", 2)
  env
}

///|
fn bind_builtin(env : Env, name : String, arity : Int) -> Unit {
  env.set(name, Value::Builtin(name, arity, []))
}

///|
fn eval(expr : Expr, env : Env) -> Value raise UiuaMLError {
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
        values.push(eval(item, env))
      }
      Value::Array(values)
    }
    Expr::Let(name, value_expr, body) => {
      let next_env = env.copy()
      next_env.set(name, eval(value_expr, env))
      eval(body, next_env)
    }
    Expr::If(cond, on_true, on_false) =>
      if truthy(eval(cond, env)) {
        eval(on_true, env)
      } else {
        eval(on_false, env)
      }
    Expr::Fun(param, body) => Value::Closure({ param, body, env: env.copy() })
    Expr::Call(callee, arg) => apply(eval(callee, env), eval(arg, env))
    Expr::Unary(op, inner) => eval_unary(op, eval(inner, env))
    Expr::Binary(op, lhs, rhs) =>
      eval_binary(op, eval(lhs, env), eval(rhs, env))
  }
}

///|
fn truthy(value : Value) -> Bool {
  match value {
    Value::Bool(b) => b
    Value::Num(n) => n != 0.0
    Value::Array(items) => !items.is_empty()
    Value::Closure(_) | Value::Builtin(_, _, _) => true
  }
}

///|
fn apply(fn_value : Value, arg : Value) -> Value raise UiuaMLError {
  match fn_value {
    Value::Closure(closure) => {
      let next_env = closure.env.copy()
      next_env.set(closure.param, arg)
      eval(closure.body, next_env)
    }
    Value::Builtin(name, arity, captured) => {
      let args = captured.copy()
      args.push(arg)
      if args.length() == arity {
        run_builtin(name, args)
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
    Value::Array(items) => {
      let result = Array::new(capacity=items.length())
      for item in items {
        result.push(negate_bools(item))
      }
      Value::Array(result)
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
    Value::Array(items) => {
      let result = Array::new(capacity=items.length())
      for item in items {
        result.push(broadcast_unary(item, f))
      }
      Value::Array(result)
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
  match (lhs, rhs) {
    (Value::Num(a), Value::Num(b)) => Value::Num(f(a, b))
    (Value::Array(xs), Value::Array(ys)) => {
      guard xs.length() == ys.length() else {
        fail("Array length mismatch: \{xs.length()} vs \{ys.length()}")
      }
      let result = Array::new(capacity=xs.length())
      let mut i = 0
      while i < xs.length() {
        result.push(broadcast_numeric(xs[i], ys[i], f))
        i = i + 1
      }
      Value::Array(result)
    }
    (Value::Array(xs), other) => {
      let result = Array::new(capacity=xs.length())
      for item in xs {
        result.push(broadcast_numeric(item, other, f))
      }
      Value::Array(result)
    }
    (other, Value::Array(ys)) => {
      let result = Array::new(capacity=ys.length())
      for item in ys {
        result.push(broadcast_numeric(other, item, f))
      }
      Value::Array(result)
    }
    _ => fail("Numeric operation expects numbers or arrays of numbers")
  }
}

///|
fn broadcast_compare(
  lhs : Value,
  rhs : Value,
  number_cmp : (Double, Double) -> Bool,
  scalar_cmp : (Value, Value) -> Bool raise UiuaMLError,
) -> Value raise UiuaMLError {
  match (lhs, rhs) {
    (Value::Num(a), Value::Num(b)) => Value::Bool(number_cmp(a, b))
    (Value::Array(xs), Value::Array(ys)) => {
      guard xs.length() == ys.length() else {
        fail("Array length mismatch: \{xs.length()} vs \{ys.length()}")
      }
      let result = Array::new(capacity=xs.length())
      let mut i = 0
      while i < xs.length() {
        result.push(broadcast_compare(xs[i], ys[i], number_cmp, scalar_cmp))
        i = i + 1
      }
      Value::Array(result)
    }
    (Value::Array(xs), other) => {
      let result = Array::new(capacity=xs.length())
      for item in xs {
        result.push(broadcast_compare(item, other, number_cmp, scalar_cmp))
      }
      Value::Array(result)
    }
    (other, Value::Array(ys)) => {
      let result = Array::new(capacity=ys.length())
      for item in ys {
        result.push(broadcast_compare(other, item, number_cmp, scalar_cmp))
      }
      Value::Array(result)
    }
    _ => Value::Bool(scalar_cmp(lhs, rhs))
  }
}

///|
fn deep_equal(lhs : Value, rhs : Value) -> Bool raise UiuaMLError {
  match (lhs, rhs) {
    (Value::Num(a), Value::Num(b)) => a == b
    (Value::Bool(a), Value::Bool(b)) => a == b
    (Value::Array(xs), Value::Array(ys)) => {
      if xs.length() != ys.length() {
        return false
      }
      let mut i = 0
      while i < xs.length() {
        if !deep_equal(xs[i], ys[i]) {
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
fn run_builtin(name : String, args : Array[Value]) -> Value raise UiuaMLError {
  match name {
    "range" | "iota" => builtin_range(args[0])
    "shape" => builtin_shape(args[0])
    "sum" => Value::Num(sum_numbers(args[0]))
    "first" => builtin_first(args[0])
    "reverse" => builtin_reverse(args[0])
    "len" => builtin_len(args[0])
    "reshape" => builtin_reshape(args[0], args[1])
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
  Value::Array(items)
}

///|
fn builtin_shape(arg : Value) -> Value raise UiuaMLError {
  Value::Array(infer_shape(arg).map(n => Value::Num(Double::from_int(n))))
}

///|
fn builtin_first(arg : Value) -> Value raise UiuaMLError {
  match arg {
    Value::Array(items) =>
      if items.is_empty() {
        fail("first expects a non-empty array")
      } else {
        items[0]
      }
    _ => fail("first expects an array")
  }
}

///|
fn builtin_reverse(arg : Value) -> Value raise UiuaMLError {
  match arg {
    Value::Array(items) => Value::Array(items.rev())
    _ => fail("reverse expects an array")
  }
}

///|
fn builtin_len(arg : Value) -> Value raise UiuaMLError {
  match arg {
    Value::Array(items) => Value::Num(Double::from_int(items.length()))
    _ => fail("len expects an array")
  }
}

///|
fn builtin_append(lhs : Value, rhs : Value) -> Value raise UiuaMLError {
  match (lhs, rhs) {
    (Value::Array(xs), Value::Array(ys)) => {
      let result = xs.copy()
      for item in ys {
        result.push(item)
      }
      Value::Array(result)
    }
    _ => fail("append expects two arrays")
  }
}

///|
fn builtin_reshape(
  shape_value : Value,
  data_value : Value,
) -> Value raise UiuaMLError {
  let shape = shape_to_dims(shape_value)
  let flat = flatten(data_value)
  guard !flat.is_empty() else { fail("reshape cannot use empty data") }
  let pair = build_shape(shape, flat, 0)
  pair.0
}

///|
fn build_shape(
  shape : Array[Int],
  flat : Array[Value],
  start : Int,
) -> (Value, Int) {
  if shape.is_empty() {
    (flat[start % flat.length()], start + 1)
  } else {
    let size = shape[0]
    let rest = shape[1:].to_owned()
    let items = Array::new(capacity=size)
    let mut next = start
    let mut i = 0
    while i < size {
      let pair = build_shape(rest, flat, next)
      items.push(pair.0)
      next = pair.1
      i = i + 1
    }
    (Value::Array(items), next)
  }
}

///|
fn shape_to_dims(value : Value) -> Array[Int] raise UiuaMLError {
  match value {
    Value::Array(items) => {
      let dims = Array::new(capacity=items.length())
      for item in items {
        dims.push(as_nat(item))
      }
      dims
    }
    _ => fail("reshape expects shape to be an array of integers")
  }
}

///|
fn infer_shape(value : Value) -> Array[Int] raise UiuaMLError {
  match value {
    Value::Array(items) => {
      let dims = [items.length()]
      if items.is_empty() {
        return dims
      }
      let child_shape = infer_shape(items[0])
      let mut i = 1
      while i < items.length() {
        guard child_shape == infer_shape(items[i]) else {
          fail("shape expects rectangular arrays")
        }
        i = i + 1
      }
      let result = dims.copy()
      for dim in child_shape {
        result.push(dim)
      }
      result
    }
    _ => []
  }
}

///|
fn flatten(value : Value) -> Array[Value] {
  match value {
    Value::Array(items) => {
      let result = Array::new()
      for item in items {
        for inner in flatten(item) {
          result.push(inner)
        }
      }
      result
    }
    _ => [value]
  }
}

///|
fn sum_numbers(value : Value) -> Double raise UiuaMLError {
  match value {
    Value::Num(n) => n
    Value::Array(items) =>
      items.fold(init=0.0, (acc, item) => acc + sum_numbers(item))
    _ => fail("sum expects numbers or arrays of numbers")
  }
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
    Value::Array(items) => {
      let body = items.map(item => item.render()).join(" ")
      "[\{body}]"
    }
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
fn render_number(n : Double) -> String {
  let i = n.to_int()
  if Double::from_int(i) == n {
    i.to_string()
  } else {
    n.to_string()
  }
}
