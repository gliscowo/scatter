import 'package:args/src/arg_results.dart';

import '../config/config.dart';
import '../log.dart';
import 'scatter_command.dart';

class InfoCommand extends ScatterCommand {
  @override
  final String name = "info";

  @override
  final String description = "Prints information about a mod stored in the database";

  @override
  void execute(ArgResults args) async {
    if (args.rest.isEmpty) throw "No mod id provided";

    var mod = ConfigManager.getMod(args.rest[0]);

    if (mod == null) {
      info("Mod not found");
    } else {
      info(mod.display_name);
    }
  }
}
