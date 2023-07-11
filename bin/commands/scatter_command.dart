import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

abstract class ScatterCommand extends Command<void> {
  final String _name, _description;
  final List<String> _arguments;

  ScatterCommand(this._name, this._description, {List<String> arguments = const []}) : _arguments = arguments;

  @override
  FutureOr<void> run() {
    if (argResults!.rest.length < _arguments.length) {
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

  @override
  String get invocation => "${super.invocation} ${_arguments.map((e) => "<$e>").join(" ")}";
}
