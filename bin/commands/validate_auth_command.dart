import 'dart:async';

import 'package:args/src/arg_results.dart';
import 'package:dart_console/dart_console.dart';

import '../adapters/host_adapter.dart';
import '../color.dart' as c;
import '../scatter.dart';
import 'scatter_command.dart';

class ValidateAuthCommand extends ScatterCommand {
  ValidateAuthCommand() : super("validate-auth", "Check the configured access tokens of each platform for validity");

  @override
  FutureOr<void> execute(ArgResults args) async {
    final results = <String, String>{};

    for (final platform in HostAdapter.platforms) {
      final adapter = HostAdapter.fromId(platform.toLowerCase());
      switch (await adapter.validateToken()) {
        case Ok():
          results[platform] = "${c.green}✓${c.reset}";
        case Error(:var error):
          results[platform] = "${c.red}⚠  $error${c.reset}";
      }
    }

    console.write(
      Table()
        ..insertRows([
          for (var MapEntry(key: platform, value: msg) in results.entries) [platform, _truncate(msg, 50)]
        ])
        ..borderType = BorderType.grid
        ..render(),
    );
  }

  String _truncate(String input, int length) {
    if (input.length <= length) return input;
    return "${input.substring(0, length)}...${c.reset}";
  }
}
