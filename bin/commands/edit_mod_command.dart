import 'package:args/src/arg_results.dart';
import 'package:console/console.dart';

import '../adapters/host_adapter.dart';
import '../config/config.dart';
import '../config/data.dart';
import '../scatter.dart';
import '../util.dart';
import 'scatter_command.dart';

class EditCommand extends ScatterCommand {
  EditCommand() : super("edit", "Edit the specified mod", requiredArgCount: 1);

  @override
  void execute(ArgResults args) async {
    var modId = args.rest[0];
    var mod = ConfigManager.requireMod(modId);

    logger.info("Editing mod '${mod.displayName}'");
    logger.info("Type 'done' to exit and save changes, 'save' to save changes");
    logger.info("Type 'quit' to exit without saving changes");

    var shell = ShellPrompt(message: "scatter > ");
    var inputEvents = shell.loop();

    await for (var input in inputEvents) {
      var args = input.split(' ');
      var command = args.removeAt(0);

      try {
        if (command == "quit") {
          shell.stop();
        } else if (command == "done") {
          ConfigManager.save<Database>();
          logger.info("Changes saved");
          shell.stop();
        } else if (command == "save") {
          ConfigManager.save<Database>();
          logger.info("Changes saved");
        } else if (command == "view") {
          mod.dumpToConsole();
        } else if (command == "help") {
          logger.info("Available commands: 'save', 'view', 'depmod', 'set', 'help'");
        } else if (command == "depmod") {
          if (args.isEmpty) throw "Missing subcommand. Usage: 'depmod <subcommand> [arguments]'";

          if (args[0] == "add") {
            if (args.length < 3) throw "Missing arguments. Usage: 'depmod add <slug> <type>'";
            var slug = args[1];
            var type = args[2];

            if (!enumMatcher(DependencyType.values)(type)) throw "Invalid dependency type";

            mod.relations.add(DependencyInfo.simple(slug, type));
            logger.info("'$slug' added as '$type' dependency");
          } else if (args[0] == "remove") {
            if (args.length < 2) throw "Missing arguments. Usage: 'depmod remove <slug>'";
            var slug = args[1];

            if (!mod.relations.any((element) => element.slug == slug)) throw "No dependency with slug '$slug' found";

            mod.relations.removeWhere((element) => element.slug == slug);
            logger.info("Dependency '$slug' removed");
          } else {
            throw "Unknown subcommand. Available: 'add', 'remove'";
          }
        } else if (command == "set") {
          if (args.length < 2) {
            throw "Missing${args.isEmpty ? " property and" : ""} value to set. ${args.isEmpty ? "Available: 'name', 'id', 'modloader', 'artifact_directory', 'filename_pattern', 'platform_id'" : ""}";
          }

          if (args[0] == "name") {
            var newName = input.substring("set name ".length);
            mod.displayName = newName;
            logger.info("Mod name changed to '$newName'");
          } else if (args[0] == "id") {
            if (args.length < 3 || args[2] != "confirm") {
              throw "This operation will forcibly save all changes and exit edit mode. Append 'confirm' to your command to execute";
            }

            ConfigManager.removeMod(mod.modId);

            mod.modId = args[1];
            ConfigManager.storeMod(mod);

            logger.info("Mod id changed to '${args[1]}'");
            logger.info("Changes saved");
            shell.stop();
          } else if (args[0] == "modloader") {
            if (!enumMatcher(Modloader.values)(args[1])) throw "Unknown modloader. Available: 'fabric', 'forge'";

            mod.modloader = args[1];
            logger.info("Modloader changed to '${args[1]}'");
          } else if (args[0] == "platform_id") {
            if (args.length < 3) throw "Missing ${args.length < 2 ? "platform and " : ""}id to set";

            var platform = args[1];
            var id = args[2];

            HostAdapter.fromId(platform);

            mod.platformIds[platform] = id;

            logger.info("'$platform' id set to '$id'");
          } else if (args[0] == "artifact_directory") {
            var dir = input.substring("set artifact_directory ".length);
            mod.artifactDirectory = dir;
            logger.info("Artifact directory set to $dir");
          } else if (args[0] == "filename_pattern") {
            var pattern = input.substring("set filename_pattern ".length);
            mod.artifactFilenamePattern = pattern;
            logger.info("Artifact filename pattern set to $pattern");
          } else {
            throw "Invalid property. Available: 'name', 'id', 'modloader', 'artifact_directory', 'filename_pattern'";
          }
        } else {
          throw "Unknown command. Available: 'save', 'view', 'depmod', 'set'";
        }
      } catch (err, stack) {
        logger.severe("Caught exception while editing mod", err, stack);
      }
    }
  }
}
