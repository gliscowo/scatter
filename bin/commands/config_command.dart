import 'package:args/src/arg_results.dart';

import '../config/config.dart';
import '../enum_utils.dart';
import '../log.dart';
import 'scatter_command.dart';

class ConfigCommand extends ScatterCommand {
  @override
  final String description = "Edit scatter's configuration";

  @override
  final String name = "config";

  ConfigCommand() {
    argParser.addOption("dump", help: "Dumps the entire config file to the console");
  }

  @override
  void execute(ArgResults args) async {
    if (args.wasParsed("dump")) {
      if (!enumMatcher(ConfigType.values)(args["dump"])) throw "Invalid config file type";
      var configType = getEnum(ConfigType.values, args["dump"]);

      print(ConfigManager.dumpConfig(configType));
      info("Config file location: ${ConfigManager.getConfigFile(configType)}");
      return;
    }

    error("No arguments provided");
  }
}
