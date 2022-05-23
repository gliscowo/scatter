import 'package:args/src/arg_results.dart';

import '../config/config.dart';
import '../log.dart';
import 'scatter_command.dart';

class InfoCommand extends ScatterCommand {
  InfoCommand() : super("info", "Prints information about a mod stored in the database", requiredArgCount: 1);

  @override
  void execute(ArgResults args) async {
    var mod = ConfigManager.getMod(args.rest[0]);

    if (mod == null) {
      info("Mod not found");
    } else {
      info("Dumping database entry for mod '${args.rest[0]}'", frame: true);
      mod.dumpToConsole();
    }
  }
}
