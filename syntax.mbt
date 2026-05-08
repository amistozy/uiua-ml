///|
priv enum TokenKind {
  Number
  Ident
  True
  False
  Fill
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
  span : SourceSpan
}

///|
fn token(kind : TokenKind, lexeme : String, span : SourceSpan) -> Token {
  { kind, lexeme, span }
}

///|
fn make_loc(offset : Int, line : Int, col : Int) -> SourceLoc {
  { offset, line, col }
}

///|
fn make_span(
  start_offset : Int,
  start_line : Int,
  start_col : Int,
  end_offset : Int,
  end_line : Int,
  end_col : Int,
) -> SourceSpan {
  {
    start: make_loc(start_offset, start_line, start_col),
    end_: make_loc(end_offset, end_line, end_col),
  }
}

///|
fn tokenize(source : StringView) -> Array[Token] raise UiuaMLError {
  let tokens = Array::new()
  let len = source.length()
  let mut i = 0
  let mut line = 1
  let mut col = 1
  while i < len {
    let ch = source.unsafe_get(i).unsafe_to_char()
    if ch.is_whitespace() {
      if ch == '\n' {
        i = i + 1
        line = line + 1
        col = 1
      } else {
        i = i + 1
        col = col + 1
      }
    } else if ch == '#' {
      i = i + 1
      col = col + 1
      while i < len && source.unsafe_get(i).unsafe_to_char() != '\n' {
        i = i + 1
        col = col + 1
      }
    } else if ch.is_digit(10) {
      let start = i
      let start_line = line
      let start_col = col
      i = i + 1
      col = col + 1
      while i < len && source.unsafe_get(i).unsafe_to_char().is_digit(10) {
        i = i + 1
        col = col + 1
      }
      if i < len && source.unsafe_get(i).unsafe_to_char() == '.' {
        i = i + 1
        col = col + 1
        while i < len && source.unsafe_get(i).unsafe_to_char().is_digit(10) {
          i = i + 1
          col = col + 1
        }
      }
      tokens.push(
        token(
          TokenKind::Number,
          source[start:i].to_owned(),
          make_span(start, start_line, start_col, i, line, col),
        ),
      )
    } else if is_ident_start(ch) {
      let start = i
      let start_line = line
      let start_col = col
      i = i + 1
      col = col + 1
      while i < len && is_ident_continue(source.unsafe_get(i).unsafe_to_char()) {
        i = i + 1
        col = col + 1
      }
      let lexeme = source[start:i].to_owned()
      tokens.push(
        token(
          keyword_or_ident(lexeme),
          lexeme,
          make_span(start, start_line, start_col, i, line, col),
        ),
      )
    } else {
      let start = i
      let start_line = line
      let start_col = col
      if i + 1 < len {
        let pair = source[i:i + 2]
        if pair == "->" {
          i = i + 2
          col = col + 2
          tokens.push(
            token(
              TokenKind::Arrow,
              "->",
              make_span(start, start_line, start_col, i, line, col),
            ),
          )
          continue
        }
        if pair == "==" {
          i = i + 2
          col = col + 2
          tokens.push(
            token(
              TokenKind::EqualEqual,
              "==",
              make_span(start, start_line, start_col, i, line, col),
            ),
          )
          continue
        }
        if pair == "!=" {
          i = i + 2
          col = col + 2
          tokens.push(
            token(
              TokenKind::BangEqual,
              "!=",
              make_span(start, start_line, start_col, i, line, col),
            ),
          )
          continue
        }
        if pair == "<=" {
          i = i + 2
          col = col + 2
          tokens.push(
            token(
              TokenKind::LessEqual,
              "<=",
              make_span(start, start_line, start_col, i, line, col),
            ),
          )
          continue
        }
        if pair == ">=" {
          i = i + 2
          col = col + 2
          tokens.push(
            token(
              TokenKind::GreaterEqual,
              ">=",
              make_span(start, start_line, start_col, i, line, col),
            ),
          )
          continue
        }
      }
      let kind = match ch {
        '(' => Some(TokenKind::LParen)
        ')' => Some(TokenKind::RParen)
        '[' => Some(TokenKind::LBracket)
        ']' => Some(TokenKind::RBracket)
        ',' => Some(TokenKind::Comma)
        '=' => Some(TokenKind::Equal)
        '+' => Some(TokenKind::Plus)
        '-' => Some(TokenKind::Minus)
        '*' => Some(TokenKind::Star)
        '/' => Some(TokenKind::Slash)
        '<' => Some(TokenKind::Less)
        '>' => Some(TokenKind::Greater)
        _ => None
      }
      guard kind is Some(kind) else {
        fail_at(
          source,
          make_span(
            start,
            start_line,
            start_col,
            start + 1,
            start_line,
            start_col + 1,
          ),
          "Unexpected character: \{ch}",
        )
      }
      i = i + 1
      col = col + 1
      tokens.push(
        token(
          kind,
          source[start:i].to_owned(),
          make_span(start, start_line, start_col, i, line, col),
        ),
      )
    }
  }
  tokens.push(token(TokenKind::Eof, "", make_span(i, line, col, i, line, col)))
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
    "fill" => TokenKind::Fill
    "if" => TokenKind::If
    "then" => TokenKind::Then
    "else" => TokenKind::Else
    "true" => TokenKind::True
    "false" => TokenKind::False
    _ => TokenKind::Ident
  }
}

///|
priv struct Expr {
  kind : ExprKind
  span : SourceSpan
}

///|
priv enum ExprKind {
  Number(Double)
  Bool(Bool)
  Var(String)
  ArrayLit(Array[Expr])
  Fill(Expr, Expr)
  Let(String, Expr, Expr)
  If(Expr, Expr, Expr)
  Fun(String, Expr)
  Call(Expr, Expr)
  Unary(String, Expr)
  Binary(String, Expr, Expr)
}

///|
fn expr(kind : ExprKind, span : SourceSpan) -> Expr {
  { kind, span }
}

///|
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int
  source : String
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
    fail_at(
      self.source,
      self.current().span,
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
    Fill => "fill"
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
  if self.eat(TokenKind::Fill) {
    return self.parse_fill()
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
fn Parser::parse_fill(self : Parser) -> Expr raise UiuaMLError {
  let keyword = self.tokens[self.pos - 1]
  let fill_value = self.parse_comparison()
  ignore(self.expect(TokenKind::In))
  let body = self.parse_expr()
  expr(ExprKind::Fill(fill_value, body), merge_spans(keyword.span, body.span))
}

///|
fn Parser::parse_let(self : Parser) -> Expr raise UiuaMLError {
  let keyword = self.tokens[self.pos - 1]
  let name = self.expect(TokenKind::Ident).lexeme
  ignore(self.expect(TokenKind::Equal))
  let value = self.parse_expr()
  ignore(self.expect(TokenKind::In))
  let body = self.parse_expr()
  expr(ExprKind::Let(name, value, body), merge_spans(keyword.span, body.span))
}

///|
fn Parser::parse_if(self : Parser) -> Expr raise UiuaMLError {
  let keyword = self.tokens[self.pos - 1]
  let cond = self.parse_expr()
  ignore(self.expect(TokenKind::Then))
  let on_true = self.parse_expr()
  ignore(self.expect(TokenKind::Else))
  let on_false = self.parse_expr()
  expr(
    ExprKind::If(cond, on_true, on_false),
    merge_spans(keyword.span, on_false.span),
  )
}

///|
fn Parser::parse_fun(self : Parser) -> Expr raise UiuaMLError {
  let keyword = self.tokens[self.pos - 1]
  let param = self.expect(TokenKind::Ident).lexeme
  ignore(self.expect(TokenKind::Arrow))
  let body = self.parse_expr()
  expr(ExprKind::Fun(param, body), merge_spans(keyword.span, body.span))
}

///|
fn Parser::parse_comparison(self : Parser) -> Expr raise UiuaMLError {
  let mut left = self.parse_additive()
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
    let right = self.parse_additive()
    left = expr(
      ExprKind::Binary(op, left, right),
      merge_spans(left.span, right.span),
    )
  }
  left
}

///|
fn Parser::parse_additive(self : Parser) -> Expr raise UiuaMLError {
  let mut left = self.parse_multiplicative()
  while true {
    let op = match self.current().kind {
      TokenKind::Plus => Some("+")
      TokenKind::Minus => Some("-")
      _ => None
    }
    guard op is Some(op) else { break }
    ignore(self.advance())
    let right = self.parse_multiplicative()
    left = expr(
      ExprKind::Binary(op, left, right),
      merge_spans(left.span, right.span),
    )
  }
  left
}

///|
fn Parser::parse_multiplicative(self : Parser) -> Expr raise UiuaMLError {
  let mut left = self.parse_application()
  while true {
    let op = match self.current().kind {
      TokenKind::Star => Some("*")
      TokenKind::Slash => Some("/")
      _ => None
    }
    guard op is Some(op) else { break }
    ignore(self.advance())
    let right = self.parse_application()
    left = expr(
      ExprKind::Binary(op, left, right),
      merge_spans(left.span, right.span),
    )
  }
  left
}

///|
fn Parser::parse_application(self : Parser) -> Expr raise UiuaMLError {
  let mut callee = self.parse_unary()
  while starts_expr(self.current().kind) {
    let arg = self.parse_unary()
    callee = expr(
      ExprKind::Call(callee, arg),
      merge_spans(callee.span, arg.span),
    )
  }
  callee
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
    | Fill
    | Let
    | Minus => true
    _ => false
  }
}

///|
fn Parser::parse_unary(self : Parser) -> Expr raise UiuaMLError {
  if self.eat(TokenKind::Minus) {
    let op = self.tokens[self.pos - 1]
    let inner = self.parse_unary()
    expr(ExprKind::Unary("-", inner), merge_spans(op.span, inner.span))
  } else {
    self.parse_primary()
  }
}

///|
fn Parser::parse_primary(self : Parser) -> Expr raise UiuaMLError {
  match self.current().kind {
    TokenKind::Number => {
      let tok = self.advance()
      let value = @string.parse_double(tok.lexeme) catch {
        _ => fail_at(self.source, tok.span, "Invalid number literal")
      }
      expr(ExprKind::Number(value), tok.span)
    }
    TokenKind::True => {
      let tok = self.advance()
      expr(ExprKind::Bool(true), tok.span)
    }
    TokenKind::False => {
      let tok = self.advance()
      expr(ExprKind::Bool(false), tok.span)
    }
    TokenKind::Ident => {
      let tok = self.advance()
      expr(ExprKind::Var(tok.lexeme), tok.span)
    }
    TokenKind::LParen => {
      let left = self.advance()
      let inner = self.parse_expr()
      let right = self.expect(TokenKind::RParen)
      expr(inner.kind, merge_spans(left.span, right.span))
    }
    TokenKind::LBracket => self.parse_array()
    _ =>
      fail_at(
        self.source,
        self.current().span,
        "Unexpected token: \{token_kind_name(self.current().kind)}",
      )
  }
}

///|
fn Parser::parse_array(self : Parser) -> Expr raise UiuaMLError {
  let left = self.expect(TokenKind::LBracket)
  let items = Array::new()
  if !self.at(TokenKind::RBracket) {
    items.push(self.parse_expr())
    while self.eat(TokenKind::Comma) {
      items.push(self.parse_expr())
    }
  }
  let right = self.expect(TokenKind::RBracket)
  expr(ExprKind::ArrayLit(items), merge_spans(left.span, right.span))
}
