import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:console/console.dart';
import 'package:http/http.dart' as http;

import 'commands/add_mod_command.dart';
import 'commands/config_command.dart';
import 'commands/edit_mod_command.dart';
import 'commands/list_game_versions_command.dart';
import 'commands/list_mods_command.dart';
import 'commands/mod_info_command.dart';
import 'commands/remove_mod_command.dart';
import 'commands/upload_command.dart';
import 'config/config.dart';
import 'log.dart';

const String version = "0.2";

final client = http.Client();
bool verbose = false;

void main(List<String> args) async {
  Console.init();

  var runner = CommandRunner("scatter", "Scatter mod distribution utility");
  runner.argParser.addFlag("verbose", negatable: false, abbr: "v", help: "Print additional debug output");
  runner.argParser.addFlag("version", negatable: false, help: "Print the version and exit");

  runner.addCommand(AddCommand());
  runner.addCommand(InfoCommand());
  runner.addCommand(ConfigCommand());
  runner.addCommand(RemoveCommand());
  runner.addCommand(UploadCommand());
  runner.addCommand(EditCommand());
  runner.addCommand(ListGameVersionsCommand());
  runner.addCommand(ListModsCommand());

  try {
    var parseResults = runner.parse(args);
    verbose = parseResults.wasParsed("verbose");

    if (parseResults.wasParsed("version")) {
      print("scatter $version");
      return;
    }

    ConfigManager.loadConfigs();

    await runner.run(args);
  } catch (err) {
    error(err);
    scatterExit(1);
  }

  scatterExit(0);
}

void scatterExit(int statusCode) {
  Console.showCursor();
  Console.resetAll();
  exit(statusCode);
}
