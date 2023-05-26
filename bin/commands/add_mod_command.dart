import 'dart:io';

import 'package:args/src/arg_results.dart';

import '../adapters/host_adapter.dart';
import '../chooser.dart';
import '../config/config.dart';
import '../config/data.dart';
import '../console.dart';
import '../scatter.dart';
import '../util.dart';
import 'scatter_command.dart';

class AddCommand extends ScatterCommand {
  AddCommand() : super("add", "Add a mod to the database", requiredArgCount: 1);

  @override
  void execute(ArgResults args) async {
    var modId = args.rest[0];

    if (ConfigManager.getMod(modId) != null) {
      throw "A mod with id '$modId' already exists in the database. Did you mean 'scatter edit $modId'?";
    }

    logger.info("Adding a new mod with id '$modId' to the database");

    var displayName = prompt("Display Name");
    var loaders = [chooseEnum(Modloader.values, message: "Modloader")];
    while (ask("Add more")) {
      loaders.add(chooseEnum(Modloader.values, message: "Modloader"));
    }

    Map<String, String> platformIds = await promptPlatformIds();

    String? artifactDirectory, artifactFilenamePattern;
    if (ask("Add artifact location")) {
      artifactDirectory = await promptValidated("Artifact directory", (path) => Directory(path).existsSync(),
          invalidMessage: "This directory does not exist");
      artifactFilenamePattern = await promptValidated("Artifact filename pattern", (input) => input.contains("{}"),
          invalidMessage: "Pattern must contain '{}' placeholder for version");
    }

    String? changelogLocation;
    if (ask("Add changelog file location")) {
      changelogLocation = prompt("Changelog file location");
    }

    List<DependencyInfo> relations = [];
    if (ask("Add dependencies")) {
      String slug, type;
      do {
        logger.info("Adding dependency");
        slug = prompt("Slug");
        type = (chooseEnum(DependencyType.values, message: "Type for dependency '$slug'")).name;
        relations.add(DependencyInfo.simple(slug, type));
      } while (ask("'$slug' added as '$type' dependency. Add more"));
    }

    var modInfo = ModInfo(displayName, modId, loaders, platformIds, relations, artifactDirectory,
        artifactFilenamePattern, changelogLocation);

    logger.info("A mod with the following information will be added to the database");

    print(modInfo.format());

    if (!ask("Commit")) return;
    ConfigManager.storeMod(modInfo);
    logger.info("Successfully added mod '${modInfo.displayName}' to the database");
  }

  static Future<Map<String, String>> promptPlatformIds() async {
    Map<String, String> platformIds = {};

    do {
      for (var platform in HostAdapter.platforms) {
        var platformId = platform.toLowerCase();
        var response = await promptValidated(
            "$platform Project Id (empty to skip)", HostAdapter.fromId(platformId).isProject,
            invalidMessage: "Invalid project id", emptyIsValid: true);
        if (response.trim().isEmpty) continue;
        platformIds[platformId] = response;
      }
      if (platformIds.isEmpty) logger.warning("You must provide at least one project id");
    } while (platformIds.isEmpty);

    return platformIds;
  }
}
