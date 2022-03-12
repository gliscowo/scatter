import 'package:args/args.dart';

import '../adapters/host_adapter.dart';
import '../log.dart';
import 'scatter_command.dart';

class ListGameVersionsCommand extends ScatterCommand {
  @override
  final String name = "list-game-versions";

  @override
  final String description = "Lists the game versions the given platform is aware of";

  ListGameVersionsCommand() {
    argParser.addOption("filter", abbr: "f");
  }

  @override
  void execute(ArgResults args) async {
    if (args.rest.isEmpty) {
      print("No platform provided");
      return;
    }

    try {
      var adapter = HostAdapter.fromId(args.rest[0]);
      var versions = await adapter.listVersions();

      if (args.wasParsed("filter")) versions.removeWhere((element) => !element.contains(args["filter"]));

      if (versions.length > 50 && !await ask("Print all ${versions.length} versions")) return;

      versions.forEach(print);
    } catch (err) {
      error(err, message: "Unable to get versions");
    }
  }
}
