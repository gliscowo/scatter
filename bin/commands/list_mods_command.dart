import 'package:args/args.dart';
import 'package:dart_console/dart_console.dart';

import '../config/config.dart';
import '../config/data.dart';
import '../scatter.dart';
import 'scatter_command.dart';

class ListModsCommand extends ScatterCommand {
  ListModsCommand() : super("list-mods", "Lists the mods in scatter's database") {
    argParser.addFlag("long", abbr: "l", help: "Print exhaustive mod information");
  }

  @override
  void execute(ArgResults args) async {
    var verbose = args.wasParsed("long");

    final mods = ConfigManager.get<Database>().mods.values;
    if (verbose) {
      for (final mod in mods) {
        print(mod.format());
      }
    } else {
      console.write(Table()
        ..insertColumn(header: "Display Name")
        ..insertColumn(header: "Mod ID")
        ..insertRows(mods.map((mod) => [mod.displayName, mod.modId]).toList())
        ..render());
    }
  }
}
