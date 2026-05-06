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
