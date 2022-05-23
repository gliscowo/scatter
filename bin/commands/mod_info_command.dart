import 'package:args/src/arg_results.dart';

import '../config/config.dart';
import '../scatter.dart';
import 'scatter_command.dart';

class InfoCommand extends ScatterCommand {
  InfoCommand() : super("info", "Prints information about a mod stored in the database", requiredArgCount: 1);

  @override
  void execute(ArgResults args) async {
    var mod = ConfigManager.getMod(args.rest[0]);

    if (mod == null) {
      logger.info("Mod not found");
    } else {
      logger.info("Dumping database entry for mod '${args.rest[0]}'");
      mod.dumpToConsole();
    }
  }
}
