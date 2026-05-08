///|
fn main {
  let eval_cmd = @argparse.Command(
    "eval",
    about="Evaluate a UiuaML expression from the command line",
    positionals=[
      @argparse.PositionArg(
        "expr",
        about="Expression to evaluate",
        num_args=@argparse.ValueRange(lower=1),
        allow_hyphen_values=true,
      ),
    ],
  )
  let run_cmd = @argparse.Command(
    "run",
    about="Read a UiuaML source file and evaluate it",
    positionals=[
      @argparse.PositionArg(
        "path",
        about="Path to a UiuaML source file",
        num_args=@argparse.ValueRange::single(),
        allow_hyphen_values=true,
      ),
    ],
  )
  let cmd = @argparse.Command(
    "uiuaml",
    about="UiuaML: an ML-like, dynamically typed array language inspired by Uiua",
    subcommand_required=true,
    subcommands=[eval_cmd, run_cmd],
  )
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
