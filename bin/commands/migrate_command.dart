import 'dart:convert';

import 'package:args/src/arg_results.dart';

import '../adapters/modrinth_adapter.dart';
import '../config/config.dart';
import '../config/data.dart';
import '../console.dart';
import '../scatter.dart';
import 'scatter_command.dart';

class MigrateCommand extends ScatterCommand {
  MigrateCommand() : super("migrate", "Utility commands for migrating/fixing old configuration data") {
    argParser.addOption("resolve-modrinth-relations",
        help:
            "Try resolving and saving the modrinth project IDs of the given mod's relations (@ for the entire database)");

    argParser.addOption("set-modrinth-relations",
        help: "Go through all existing versions of a mod and add the relations from the database");

    argParser.addOption("clear-featured-flag",
        help: "Remove the featured flag from all versions of the given mod on Modrinth");
  }

  @override
  void execute(ArgResults args) async {
    if (args.wasParsed("resolve-modrinth-relations")) {
      await _executeResolveRelations(args);
    } else if (args.wasParsed("set-modrinth-relations")) {
      await _executeSetRelations(args);
    } else if (args.wasParsed("clear-featured-flag")) {
      await _executeClearFeaturedFlag(args);
    } else {
      printUsage();
    }
  }

  Future<void> _executeClearFeaturedFlag(ArgResults args) async {
    final modrinth = ModrinthAdapter.instance;
    final modId = args["clear-featured-flag"] as String;
    // ConfigManager.requireMod(modId);

    logger.info("Loading versions");

    final versions = await modrinth.api.getProjectVersions(modId);
    if (versions == null) {
      throw "Could not query versions for mod id $modId";
    }

    print("");

    for (final version in versions) {
      logger.info("Patching version ${version.name}");
      final response = await client.patch(
        modrinth.resolve("version/${version.id}"),
        body: jsonEncode({"featured": false}),
        headers: {"Content-Type": "application/json", ...modrinth.authHeader()},
      );

      if (response.statusCode != 204) {
        logger.warning("Could not patch -> ${response.body}");
      }

      await Future.delayed(Duration(milliseconds: 1500));
    }
  }

  Future<void> _executeSetRelations(ArgResults args) async {
    final modrinth = ModrinthAdapter.instance;
    final modId = args["set-modrinth-relations"] as String;
    final mod = ConfigManager.requireMod(modId);

    final oldestVersion = await prompt("Oldest applicable version (empty for none)");

    logger.info("Adding the following currently stored relations to all versions of '${mod.displayName}' "
        "on Modrinth, backtracking until the given oldest applicable one");

    final applicableRelations = mod.relations.where((element) => element.projectIds.containsKey(modrinth.id));
    if (applicableRelations.isEmpty) {
      throw "No relations with known Modrinth IDs found";
    }

    for (var relation in applicableRelations) {
      print(" - ${relation.slug}");
    }

    if (!await ask("\nProceed")) return;

    final versionList = await modrinth.fetchUnchecked("project/${modrinth.idOf(mod)}/version");
    logger.fine("Version query response: $versionList");
    if (versionList is! List<dynamic>) throw "Invalid API response";

    if (!versionList.any((element) => element["version_number"] == oldestVersion)) {
      throw "Oldest applicable version does not exist on modrinth";
    }

    for (var version in versionList) {
      if (version is! Map<String, dynamic>) continue;

      logger.info("Patching version ${version["version_number"]}");

      var deps = version["dependencies"] as List<dynamic>;
      for (var relation in mod.relations) {
        var modrinthId = relation.projectIds[modrinth.id];
        if (modrinthId == null) continue;

        if (await _projectIdContained(
            deps.map((e) => e["version_id"]).where((element) => element != null).cast<String>(), modrinthId)) {
          logger.info("Dependency ${relation.slug} already present, skipping");
          continue;
        }

        deps.add({"dependency_type": relation.type == "optional" ? "optional" : "required", "project_id": modrinthId});
      }

      final encoded = jsonEncode({"dependencies": version["dependencies"]});

      var headers = modrinth.authHeader();
      headers["Content-Type"] = "application/json";

      final result = await client.patch(modrinth.resolve("version/${version["id"]}"), body: encoded, headers: headers);

      if (result.statusCode != 204) {
        logger.warning("Could not modify version", result.body);
      }

      if (version["version_number"] == oldestVersion) {
        logger.info("Oldest applicable version encountered, stopping");
        break;
      }
    }
  }

  Future<void> _executeResolveRelations(ArgResults args) async {
    final modId = args["resolve-modrinth-relations"] as String;

    if (modId == "@") {
      var mods = ConfigManager.get<Database>().mods.values;
      logger.info("Resolving dependencies for mods [${mods.map((e) => e.displayName).join(", ")}]");
      for (var mod in mods) {
        await _tryResolveRelations(mod);
      }
    } else {
      final mod = ConfigManager.requireMod(modId);
      logger.info("Resolving dependencies for mod $modId");
      await _tryResolveRelations(mod);
    }
  }

  Future<bool> _projectIdContained(Iterable<String> versionIds, String projectId) async {
    for (var version in versionIds) {
      if ((await ModrinthAdapter.instance.api.getVersion(version))?.projectId == projectId) {
        return true;
      }
    }
    return false;
  }

  Future<void> _tryResolveRelations(ModInfo mod) async {
    var modified = false;

    for (var relation in mod.relations) {
      if (relation.projectIds.containsKey(ModrinthAdapter.instance.id)) continue;

      final id = (await ModrinthAdapter.instance.api.getProject(relation.slug))?.id;
      if (id != null) {
        relation.projectIds[ModrinthAdapter.instance.id] = id;
        logger.info("Fetched modrinth id $id for relation ${relation.slug}");
        modified = true;
      } else {
        logger.warning("Could not fetch project id for relation '${relation.slug}'");
      }
    }

    if (modified) ConfigManager.storeMod(mod);
  }
}
