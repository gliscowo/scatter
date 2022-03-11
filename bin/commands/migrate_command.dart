import 'package:args/src/arg_results.dart';

import '../adapters/modrinth_adapter.dart';
import '../config/config.dart';
import '../config/data.dart';
import '../log.dart';
import 'scatter_command.dart';

class MigrateCommand extends ScatterCommand {
  @override
  final String name = "migrate";

  @override
  final String description = "Utility commands for migrating/fixing old configuration data";

  MigrateCommand() {
    argParser.addOption("resolve-modrinth-relations",
        help:
            "Try resolving and saving the modrinth project IDs of the given mod's relations (@ for the entire database)");
  }

  @override
  void execute(ArgResults args) async {
    if (args.wasParsed("resolve-modrinth-relations")) {
      final modSlug = args["resolve-modrinth-relations"];

      if (modSlug == "@") {
        var mods = ConfigManager.getConfigObject(ConfigType.database).mods.values;
        info("Resolving dependencies for mods [${mods.map((e) => e.display_name).join(", ")}]", frame: true);
        for (var mod in mods) {
          await _tryResolveRelations(mod);
        }
      } else {
        final mod = ConfigManager.getMod(modSlug);
        if (mod == null) throw "Unknown mod";

        info("Resolving dependencies for mod $modSlug");
        await _tryResolveRelations(mod);
      }
    }

    await ModrinthAdapter.instance.getIdFromSlug("owo-lib");
  }

  Future<void> _tryResolveRelations(ModInfo mod) async {
    var modified = false;

    for (var relation in mod.relations) {
      if (relation.project_ids.containsKey(ModrinthAdapter.instance.id)) continue;

      final id = await ModrinthAdapter.instance.getIdFromSlug(relation.slug);
      if (id != null) {
        relation.project_ids[ModrinthAdapter.instance.id] = id;
        info("Fetched modrinth id $id for relation ${relation.slug}");
        modified = true;
      } else {
        error("Could not fetch project id for relation '${relation.slug}'");
      }
    }

    if (modified) ConfigManager.storeMod(mod);
  }
}
