///|
test "root help snapshot" {
  inspect(
    build_cli().render_help(),
    content=(
      #|Usage: uiuaml <command>
      #|
      #|UiuaML is a small experimental array language implemented in MoonBit.
      #|
      #|It uses an expression-oriented, ML-flavored syntax inspired by Uiua.
      #|
      #|Common commands:
      #|  uiuaml eval "shape [[1, 2], [3, 4]]"
      #|  uiuaml run program.ua
      #|
      #|Commands:
      #|  eval  Evaluate a single UiuaML expression.
      #|  run   Read a UiuaML source file and evaluate it.
      #|  help  Print help for the subcommand(s).
      #|
      #|Options:
      #|  -h, --help  Show help information.
      #|
    ),
  )
}

///|
test "eval help snapshot" {
  inspect(
    build_eval_cmd().render_help(),
    content=(
      #|Usage: eval <expr...>
      #|
      #|Evaluate a single UiuaML expression.
      #|
      #|Arguments:
      #|  expr...  A UiuaML expression. Multiple shell arguments are joined with spaces.
      #|
      #|Options:
      #|  -h, --help  Show help information.
      #|
    ),
  )
}

///|
test "run help snapshot" {
  inspect(
    build_run_cmd().render_help(),
    content=(
      #|Usage: run <path>
      #|
      #|Read a UiuaML source file and evaluate it.
      #|
      #|Arguments:
      #|  path  Path to a UTF-8 text file containing a UiuaML program.
      #|
      #|Options:
      #|  -h, --help  Show help information.
      #|
    ),
  )
}
