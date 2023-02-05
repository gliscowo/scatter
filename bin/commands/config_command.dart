import 'dart:io';

import 'package:args/src/arg_results.dart';

import '../adapters/host_adapter.dart';
import '../chooser.dart';
import '../config/config.dart';
import '../config/data.dart';
import '../console.dart';
import '../scatter.dart';
import 'scatter_command.dart';
import 'upload_command.dart';

class ConfigCommand extends ScatterCommand {
  ConfigCommand() : super("config", "Edit scatter's configuration") {
    argParser.addOption("dump", help: "Dumps the entire config file to the console");
    argParser.addFlag("tokens", help: "Manage the stored access tokens", negatable: false);
    argParser.addFlag("default-versions",
        help: "Change the default versions all uploaded files are marked compatible with", negatable: false);
    argParser.addFlag("export", help: "Export scatter's configuration", negatable: false);
    argParser.addOption("import", help: "Import a config export from the given file");
    argParser.addFlag("set-changelog-mode", help: "Configure the default changelog mode", negatable: false);
  }

  @override
  void execute(ArgResults args) async {
    if (args.wasParsed("dump")) {
      var configType = ConfigManager.typesByName[args["dump"]];
      if (configType == null) throw "Invalid config file type";

      print(ConfigManager.dumpObject(configType));
      logger.info("Config file location: ${ConfigManager.getFilePath(configType)}");
    } else if (args.wasParsed("export")) {
      var exportFile = File("scatter_config_export.json");
      if (exportFile.existsSync() && !await ask("File '${exportFile.path}' already exists. Overwrite")) return;

      exportFile.writeAsStringSync(ConfigManager.export());
      logger.info("Config exported to '${exportFile.path}'");
    } else if (args.wasParsed("import")) {
      var exportFile = File(args["import"]);
      if (!exportFile.existsSync()) throw "File does not exist";

      ConfigManager.import(exportFile.readAsStringSync());
      logger.info("Config imported");
    } else if (args.wasParsed("set-changelog-mode")) {
      final config = ConfigManager.get<Config>();
      final mode =
          await chooseEnum(ChangelogMode.values, message: "Changelog mode", selected: config.defaultChangelogMode);

      config.defaultChangelogMode = mode;
      ConfigManager.save<Config>();

      logger.info("Default changelog mode updated to '${mode.name}'");
    } else if (args.wasParsed("tokens")) {
      var platform = HostAdapter.fromId(
          (await EntryChooser.horizontal(HostAdapter.platforms, message: "Platform").choose()).toLowerCase());
      var token = await prompt("Token (empty to remove)", secret: true);
      stdin.echoMode = true;
      print("");

      if (token.trim().isEmpty) {
        ConfigManager.setToken(platform.id, null);
        logger.info("Token for platform '${platform.id}' removed");
      } else {
        ConfigManager.setToken(platform.id, token);
        logger.info("Token for platform '${platform.id}' updated");
      }
    } else if (args.wasParsed("default-versions")) {
      logger.info("Editing default versions. Prefix with '-' to remove a version, leave empty to exit");
      logger.info("Use '-' to clear, '#' to display current default versions");
      logger.info("Current default versions: ${ConfigManager.getDefaultVersions()}");

      String version;
      do {
        version = (await prompt("Version")).trim();

        if (version == "#") {
          logger.info("Current default versions: ${ConfigManager.getDefaultVersions()}");
        } else if (version.startsWith("-")) {
          if (version.substring(1).isEmpty) {
            ConfigManager.getDefaultVersions().clear();
            ConfigManager.save<Config>();
            logger.info("Default versions successfully cleared");
          } else {
            if (ConfigManager.removeDefaultVersion(version.substring(1))) {
              logger.info("Version '${version.substring(1)}' successfully removed from default versions");
            } else {
              logger.warning("Version '${version.substring(1)}' was not a default version");
            }
          }
        } else if (version.isNotEmpty) {
          if (ConfigManager.addDefaultVersion(version)) {
            logger.info("Version '$version' successfully added to default versions");
          } else {
            logger.warning("Version '$version' is already a default version");
          }
        }
      } while (version.isNotEmpty);
    }

    if (args.arguments.isEmpty) printUsage();
  }
}
