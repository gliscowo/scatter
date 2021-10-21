import 'package:args/src/arg_results.dart';
import 'package:console/console.dart';

import '../adapters/host_adapter.dart';
import '../config//data.dart';
import '../enum_utils.dart';
import '../log.dart';
import 'scatter_command.dart';

class AddCommand extends ScatterCommand {
  @override
  final String name = "add";

  @override
  final String description = "Add a mod to the database";

  @override
  void execute(ArgResults args) async {
    if (args.rest.isEmpty) throw "No mod id provided";

    var modId = args.rest[0];
    info("Adding a new mod with id '$modId' to the database\n");

    var displayName = await prompt("Display Name");
    var modloader = await promptValidated("Modloader", enumMatcher(Modloader.values), invalidMessage: "Unknown modloader");

    Map<String, String> platformIds = await promptPlatformIds();

    String? artifactDirectory, artifactFilenamePattern;
    if (await ask("Add artifact location")) {
      artifactDirectory = await prompt("Artifact directory");
      artifactFilenamePattern = await prompt("Artifact filename pattern");
    }
  }

  static Future<Map<String, String>> promptPlatformIds() async {
    Map<String, String> platformIds = {};

    do {
      for (var platform in HostAdapter.platforms) {
        var response = await prompt("$platform Project Id (empty to skip)");
        if (response.isEmpty) continue;
        platformIds[platform.toLowerCase()] = response;
      }
      if (platformIds.isEmpty) info("You must provide at least one project id", frame: true);
    } while (platformIds.isEmpty);

    return platformIds;
  }
}
