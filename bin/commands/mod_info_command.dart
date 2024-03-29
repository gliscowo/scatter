import 'package:args/src/arg_results.dart';

import '../config/config.dart';
import '../scatter.dart';
import 'scatter_command.dart';

class InfoCommand extends ScatterCommand {
  InfoCommand() : super("info", "Prints information about a mod stored in the database", arguments: ["mod-id"]);

  @override
  void execute(ArgResults args) async {
    var mod = ConfigManager.getMod(args.rest[0]);

    if (mod == null) {
      logger.warning("Mod not found");
    } else {
      print(mod.format());
    }
  }
}
