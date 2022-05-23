import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

abstract class ScatterCommand extends Command<void> {
  final String _name, _description;
  final int _requiredArgCount;

  ScatterCommand(this._name, this._description, {int requiredArgCount = 0}) : _requiredArgCount = requiredArgCount;

  @override
  FutureOr<void> run() {
    if (argResults!.rest.length < _requiredArgCount) {
      printUsage();
      return null;
    }
    return execute(argResults!);
  }

  FutureOr<void> execute(ArgResults args);

  @override
  String get name => _name;
  @override
  String get description => _description;
}
