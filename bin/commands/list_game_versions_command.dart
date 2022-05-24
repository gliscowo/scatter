import 'package:args/args.dart';

import '../adapters/host_adapter.dart';
import '../console.dart';
import '../scatter.dart';
import 'scatter_command.dart';

class ListGameVersionsCommand extends ScatterCommand {
  ListGameVersionsCommand()
      : super("list-game-versions", "Lists the game versions the given platform is aware of", requiredArgCount: 1) {
    argParser.addOption("filter", abbr: "f");
  }

  @override
  void execute(ArgResults args) async {
    try {
      var adapter = HostAdapter.fromId(args.rest[0]);
      var versions = await adapter.listVersions();

      if (args.wasParsed("filter")) versions.removeWhere((element) => !element.contains(args["filter"]));

      if (versions.length > 50 && !await ask("Print all ${versions.length} versions")) return;

      versions.forEach(print);
    } catch (err, stack) {
      logger.severe("Could not list versions", err, stack);
    }
  }
}
