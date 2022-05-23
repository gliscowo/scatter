import 'dart:io';

import 'package:args/src/arg_results.dart';

import '../adapters/host_adapter.dart';
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

    var displayName = await prompt("Display Name");
    var modloader =
        await promptValidated("Modloader", enumMatcher(Modloader.values), invalidMessage: "Unknown modloader");

    Map<String, String> platformIds = await promptPlatformIds();

    String? artifactDirectory, artifactFilenamePattern;
    if (await ask("Add artifact location")) {
      artifactDirectory =
          await promptValidated("Artifact directory", isDirectory, invalidMessage: "This directory does not exist");
      artifactFilenamePattern = await promptValidated("Artifact filename pattern", (input) => input.contains("{}"),
          invalidMessage: "Pattern must contain '{}' placeholder for version");
    }

    List<DependencyInfo> relations = [];
    if (await ask("Add dependencies")) {
      String slug, type;
      do {
        logger.info("Adding dependency");
        slug = await prompt("Slug");
        type = await promptValidated("Type for dependency '$slug'", enumMatcher(DependencyType.values),
            invalidMessage: "Unknown dependency type");
        relations.add(DependencyInfo.simple(slug, type));
      } while (await ask("'$slug' added as '$type' dependency. Add more"));
    }

    var modInfo =
        ModInfo(displayName, modId, modloader, platformIds, relations, artifactDirectory, artifactFilenamePattern);

    logger.info("A mod with the following information will be added to the database");

    modInfo.dumpToConsole();

    if (!await ask("Commit")) return;
    ConfigManager.storeMod(modInfo);
    logger.info("Successfully added mod '${modInfo.displayName}' to the database");
  }

  bool isDirectory(String dir) {
    return Directory(dir).existsSync();
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
      if (platformIds.isEmpty) logger.info("You must provide at least one project id");
    } while (platformIds.isEmpty);

    return platformIds;
  }
}
