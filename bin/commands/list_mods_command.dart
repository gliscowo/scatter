import 'package:args/args.dart';

import '../config/config.dart';
import '../config/data.dart';
import '../console.dart';
import '../util.dart';
import 'scatter_command.dart';

class ListModsCommand extends ScatterCommand {
  ListModsCommand() : super("list-mods", "Lists the mods in scatter's database") {
    argParser.addFlag("long", abbr: "l", help: "Print exhaustive mod information");
  }

  @override
  void execute(ArgResults args) async {
    var verbose = args.wasParsed("long");

    ConfigManager.get<Database>().mods.forEach((id, mod) {
      if (verbose) {
        mod.formatted().printLines();
        print("");
      } else {
        printKeyValuePair(id, mod.displayName);
      }
    });
  }
}
