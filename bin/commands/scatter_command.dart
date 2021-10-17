import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

abstract class ScatterCommand extends Command {
  @override
  void run() async {
    if (argResults == null) throw "Argument parsing failed";
    await execute(argResults!);
  }

  FutureOr<void> execute(ArgResults args);
}
