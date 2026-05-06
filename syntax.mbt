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
    Number
    | Ident
    | True
    | False
    | LParen
    | LBracket
    | If
    | Fun
    | Let
    | Minus => true
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
      let value = @string.parse_double(self.advance().lexeme) catch {
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
