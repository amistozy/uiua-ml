///|
struct SourceLoc {
  offset : Int
  line : Int
  col : Int
} derive(Eq, Debug)

///|
struct SourceSpan {
  start : SourceLoc
  end_ : SourceLoc
} derive(Eq, Debug)

///|
fn merge_spans(lhs : SourceSpan, rhs : SourceSpan) -> SourceSpan {
  if lhs.start.offset <= rhs.start.offset {
    if lhs.end_.offset >= rhs.end_.offset {
      lhs
    } else {
      { start: lhs.start, end_: rhs.end_ }
    }
  } else {
    merge_spans(rhs, lhs)
  }
}

///|
pub suberror UiuaMLError {
  UiuaMLError(String, String)
} derive(Eq, Debug)

///|
pub impl Show for UiuaMLError with output(self, logger) {
  match self {
    UiuaMLError(_, rendered) => logger.write_string(rendered)
  }
}

///|
pub fn interpret(source : StringView) -> String raise UiuaMLError {
  let parser = Parser::{
    tokens: tokenize(source),
    pos: 0,
    source: source.to_owned(),
  }
  let expr = parser.parse_expr()
  ignore(parser.expect(TokenKind::Eof))
  eval(expr, default_env(), source).render()
}

///|
fn[T] fail(message : String) -> T raise UiuaMLError {
  raise UiuaMLError(message, message)
}

///|
fn[T] fail_at(
  source : StringView,
  span : SourceSpan,
  message : String,
) -> T raise UiuaMLError {
  raise UiuaMLError(message, render_error(message, source, span))
}

///|
fn error_message(err : UiuaMLError) -> String {
  match err {
    UiuaMLError(message, _) => message
  }
}

///|
fn error_has_context(err : UiuaMLError) -> Bool {
  match err {
    UiuaMLError(message, rendered) => message != rendered
  }
}

///|
fn annotate_error(
  err : UiuaMLError,
  source : StringView,
  span : SourceSpan,
) -> UiuaMLError {
  if error_has_context(err) {
    err
  } else {
    let message = error_message(err)
    UiuaMLError(message, render_error(message, source, span))
  }
}

///|
fn render_error(
  message : String,
  source : StringView,
  span : SourceSpan,
) -> String {
  let line_start = find_line_start(source, span.start.offset)
  let line_end = find_line_end(source, span.start.offset)
  let line_text = source[line_start:line_end].to_owned()
  let underline_width = if span.start.line == span.end_.line {
    (span.end_.col - span.start.col).max(1)
  } else {
    (line_text.length() - (span.start.offset - line_start)).max(1)
  }
  let prefix = "\{span.start.line} | "
  let caret_pad = " ".repeat(prefix.length() + span.start.col - 1)
  let underline = "^".repeat(underline_width)
  (
    $|\{message}
    $|  at \{span.start.line}:\{span.start.col}
    $|\{prefix}\{line_text}
    $|\{caret_pad}\{underline}
  )
}

///|
fn find_line_start(source : StringView, offset : Int) -> Int {
  let mut i = offset
  while i > 0 && source.unsafe_get(i - 1).unsafe_to_char() != '\n' {
    i = i - 1
  }
  i
}

///|
fn find_line_end(source : StringView, offset : Int) -> Int {
  let len = source.length()
  let mut i = offset
  while i < len && source.unsafe_get(i).unsafe_to_char() != '\n' {
    i = i + 1
  }
  i
}
