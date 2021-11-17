import 'package:args/args.dart';

import '../config/config.dart';
import '../log.dart';
import 'scatter_command.dart';

class ListModsCommand extends ScatterCommand {
  @override
  final String name = "list-mods";

  @override
  final String description = "Lists the mods in scatter's database";

  ListModsCommand() {
    argParser.addFlag("long", abbr: "l", help: "Print exhaustive mod information");
  }

  @override
  void execute(ArgResults args) async {
    var verbose = args.wasParsed("long");

    ConfigManager.getConfigObject(ConfigType.database).mods.forEach((id, mod) {
      if (verbose) {
        mod.dumpToConsole();
        print("");
      } else {
        printKeyValuePair(id, mod.display_name);
      }
    });
  }
}
