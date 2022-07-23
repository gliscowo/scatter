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
  }

  @override
  void execute(ArgResults args) async {
    if (args.wasParsed("resolve-modrinth-relations")) {
      await _executeResolveRelations(args);
    } else if (args.wasParsed("set-modrinth-relations")) {
      await _executeSetRelations(args);
    } else {
      printUsage();
    }
  }

  Future<void> _executeSetRelations(ArgResults args) async {
    final modrinth = ModrinthAdapter.instance;
    final modId = args["set-modrinth-relations"] as String;
    final mod = ConfigManager.requireMod(modId);

    final oldestVersion = await prompt("Oldest applicable version (empty for none)");

    logger.info("Adding the following currently stored relations to all versions of '${mod.displayName}' "
        "on Modrinth, backtracking until the given oldest applicable one");

    final applicableRelations = mod.relations.where((element) => element.project_ids.containsKey(modrinth.id));
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
        var modrinthId = relation.project_ids[modrinth.id];
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
      if (await ModrinthAdapter.instance.projectIdFromVersion(version) != projectId) continue;
      return true;
    }
    return false;
  }

  Future<void> _tryResolveRelations(ModInfo mod) async {
    var modified = false;

    for (var relation in mod.relations) {
      if (relation.project_ids.containsKey(ModrinthAdapter.instance.id)) continue;

      final id = await ModrinthAdapter.instance.getIdFromSlug(relation.slug);
      if (id != null) {
        relation.project_ids[ModrinthAdapter.instance.id] = id;
        logger.info("Fetched modrinth id $id for relation ${relation.slug}");
        modified = true;
      } else {
        logger.warning("Could not fetch project id for relation '${relation.slug}'");
      }
    }

    if (modified) ConfigManager.storeMod(mod);
  }
}
