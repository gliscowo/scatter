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
  }

  @override
  void execute(ArgResults args) async {
    if (args.wasParsed("dump")) {
      var configType = ConfigType.get(args["dump"]);
      if (configType == null) throw "Invalid config file type";

      print(ConfigManager.dumpConfig(configType));
      info("Config file location: ${ConfigManager.getConfigFile(configType)}");
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
    }

    error("No arguments provided");
  }
}
