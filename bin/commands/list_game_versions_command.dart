import 'package:args/args.dart';

import '../adapters/host_adapter.dart';
import '../console.dart';
import '../scatter.dart';
import 'scatter_command.dart';

class ListGameVersionsCommand extends ScatterCommand {
  ListGameVersionsCommand()
      : super(
          "list-game-versions",
          "Lists the game versions the given platform is aware of",
          arguments: ["platform-id"],
        ) {
    argParser.addOption(
      "filter",
      abbr: "f",
      help: "A search string to filter the game versions by",
    );
  }

  @override
  void execute(ArgResults args) async {
    try {
      var adapter = HostAdapter.fromId(args.rest[0]);
      var versions = await adapter.listVersions();

      if (args.wasParsed("filter")) versions.removeWhere((element) => !element.contains(args["filter"] as String));

      if (versions.length > 50 && !ask("Print all ${versions.length} versions")) return;

      versions.forEach(print);
    } catch (err, stack) {
      logger.severe("Could not list versions", err, stack);
    }
  }
}
