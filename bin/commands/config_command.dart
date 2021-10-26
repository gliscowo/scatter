import 'dart:io';

import 'package:args/src/arg_results.dart';

import '../adapters/host_adapter.dart';
import '../config/config.dart';
import '../log.dart';
import 'scatter_command.dart';

class ConfigCommand extends ScatterCommand {
  @override
  final String description = "Edit scatter's configuration";

  @override
  final String name = "config";

  ConfigCommand() {
    argParser.addOption("dump", help: "Dumps the entire config file to the console");
    argParser.addOption("set-token", help: "Set the token for the given platform");
    argParser.addFlag("default-versions", help: "Change the default versions all uploaded files are marked compatible with", negatable: false);
    argParser.addFlag("export", help: "Export scatter's configuration", negatable: false);
    argParser.addOption("import", help: "Import a config export from the given file");
  }

  @override
  void execute(ArgResults args) async {
    if (args.wasParsed("dump")) {
      var configType = ConfigType.get(args["dump"]);
      if (configType == null) throw "Invalid config file type";

      print(ConfigManager.dumpConfig(configType));
      info("Config file location: ${ConfigManager.getConfigFile(configType)}");
      return;
    } else if (args.wasParsed("export")) {
      var exportFile = File("scatter_config_export.json");
      if (exportFile.existsSync() && !await ask("File '${exportFile.path}' already exists. Overwrite")) return;

      exportFile.writeAsStringSync(ConfigManager.export());
      info("Config exported to '${exportFile.path}'");
      return;
    } else if (args.wasParsed("import")) {
      var exportFile = File(args["import"]);
      if (!exportFile.existsSync()) throw "File does not exist";

      ConfigManager.import(exportFile.readAsStringSync());
      info("Config imported");
      return;
    } else if (args.wasParsed("set-token")) {
      var platform = HostAdapter(args["set-token"]);
      var token = await prompt("Token (empty to remove)", secret: true);
      print("");

      if (token.trim().isEmpty) {
        ConfigManager.setToken(platform.getId(), null);
        info("Token for platform '${platform.getId()}' removed", frame: true);
      } else {
        ConfigManager.setToken(platform.getId(), token);
        info("Token for platform '${platform.getId()}' updated", frame: true);
      }

      return;
    } else if (args.wasParsed("default-versions")) {
      info("Editing default versions. Prefix with '-' to remove a version, leave empty to exit");
      info("Use '-' to clear, '#' to display current default versions");
      info("Current default versions: ${ConfigManager.getDefaultVersions()}");

      String version;
      do {
        version = (await prompt("Version")).trim();

        if (version == "#") {
          info("Current default versions: ${ConfigManager.getDefaultVersions()}");
        } else if (version.startsWith("-")) {
          if (version.substring(1).isEmpty) {
            ConfigManager.getDefaultVersions().clear();
            ConfigManager.save(ConfigType.config);
            info("Default versions successfully cleared");
          } else {
            if (ConfigManager.removeDefaultVersion(version.substring(1))) {
              info("Version '${version.substring(1)}' successfully removed from default versions");
            } else {
              error("Version '${version.substring(1)}' was not a default version");
            }
          }
        } else if (version.isNotEmpty) {
          if (ConfigManager.addDefaultVersion(version)) {
            info("Version '$version' successfully added to default versions");
          } else {
            error("Version '$version' is already a default version");
          }
        }
      } while (version.isNotEmpty);

      return;
    }

    error("No arguments provided");
  }
}
