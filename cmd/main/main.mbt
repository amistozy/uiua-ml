///|
fn build_eval_cmd() -> @argparse.Command {
  @argparse.Command("eval", about="Evaluate a single UiuaML expression.", positionals=[
    @argparse.PositionArg(
      "expr",
      about="A UiuaML expression. Multiple shell arguments are joined with spaces.",
      num_args=@argparse.ValueRange(lower=1),
      allow_hyphen_values=true,
    ),
  ])
}

///|
fn build_run_cmd() -> @argparse.Command {
  @argparse.Command("run", about="Read a UiuaML source file and evaluate it.", positionals=[
    @argparse.PositionArg(
      "path",
      about="Path to a UTF-8 text file containing a UiuaML program.",
      num_args=@argparse.ValueRange::single(),
      allow_hyphen_values=true,
    ),
  ])
}

///|
fn build_cli() -> @argparse.Command {
  @argparse.Command(
    "uiuaml",
    about=(
      #|UiuaML is a small experimental array language implemented in MoonBit.
      #|
      #|It uses an expression-oriented, ML-flavored syntax inspired by Uiua.
      #|
      #|Common commands:
      #|  uiuaml eval "shape [[1, 2], [3, 4]]"
      #|  uiuaml run program.ua
    ),
    subcommand_required=true,
    subcommands=[build_eval_cmd(), build_run_cmd()],
  )
}

///|
fn main {
  let cmd = build_cli()
  let matches = cmd.parse(argv=@env.args()[1:], env={}) catch {
    err => {
      println(err.to_string())
      return
    }
  }
  match matches.subcommand {
    Some(("eval", sub)) => {
      let source = match sub.values {
        { "expr": parts, .. } => parts.join(" ")
        _ => {
          println("missing expr")
          return
        }
      }
      interpret_and_print(source)
    }
    Some(("run", sub)) => {
      let path = match sub.values {
        { "path": [path], .. } => path
        _ => {
          println("missing path")
          return
        }
      }
      let source = @fs.read_file_to_string(path) catch {
        err => {
          println("UiuaML I/O error: \{@debug.to_string(err)}")
          return
        }
      }
      interpret_and_print(source)
    }
    _ => {
      println("missing subcommand")
      return
    }
  }
}

///|
fn interpret_and_print(source : String) -> Unit {
  (@uiuaml.interpret(source) |> println) catch {
    @uiuaml.UiuaMLError(_, rendered) => println("UiuaML error: \{rendered}")
  }
}
