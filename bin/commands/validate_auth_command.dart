import 'dart:async';

import 'package:args/src/arg_results.dart';

import '../adapters/host_adapter.dart';
import '../color.dart' as c;
import 'scatter_command.dart';

class ValidateAuthCommand extends ScatterCommand {
  ValidateAuthCommand() : super("validate-auth", "Check the configured access tokens of each platform for validity");

  @override
  FutureOr<void> execute(ArgResults args) async {
    for (final platform in HostAdapter.platforms) {
      final adapter = HostAdapter.fromId(platform.toLowerCase());
      switch (await adapter.validateToken()) {
        case Ok():
          print("$platform: ${c.green}✓${c.reset}");
        case Error(:var error):
          print("$platform: ${c.red}⚠  $error${c.reset}");
      }
    }
  }
}
