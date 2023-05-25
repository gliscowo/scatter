import 'dart:async';

import 'package:args/src/arg_results.dart';
import 'package:console/console.dart';

import '../adapters/host_adapter.dart';
import 'scatter_command.dart';

class ValidateAuthCommand extends ScatterCommand {
  ValidateAuthCommand() : super("validate-auth", "Check the configured access tokens of each platform for validity");

  @override
  FutureOr<void> execute(ArgResults args) async {
    for (final platform in HostAdapter.platforms) {
      final adapter = HostAdapter.fromId(platform.toLowerCase());
      switch (await adapter.validateToken()) {
        case Ok():
          print(TextPen()
            ..text("$platform: ")
            ..green()
            ..text("✓")
            ..normal());
        case Error(:var error):
          print(TextPen()
            ..text("$platform: ")
            ..red()
            ..text("⚠  ")
            ..normal()
            ..text(error));
      }
    }
  }
}
