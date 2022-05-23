import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:console/console.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'commands/add_mod_command.dart';
import 'commands/config_command.dart';
import 'commands/edit_mod_command.dart';
import 'commands/list_game_versions_command.dart';
import 'commands/list_mods_command.dart';
import 'commands/migrate_command.dart';
import 'commands/mod_info_command.dart';
import 'commands/remove_mod_command.dart';
import 'commands/upload_command.dart';
import 'config/config.dart';

const String version = "0.2";

final client = http.Client();
bool verbose = false;

final logger = Logger("scatter");

void main(List<String> args) async {
  Console.init();

  Logger.root.onRecord.listen((event) {
    final pen = TextPen()
        .setColor(levelToColor(event.level))
        .text(event.level.name.toLowerCase())
        .white()
        .text(": ")
        .normal()
        .text(event.message);
    if (event.error != null) {
      if (verbose) {
        pen.text("${event.error}");
      } else {
        pen.text("(run with -v to see error details)");
      }
    }
    pen.print();
  });

  var runner = CommandRunner<void>("scatter", "Scatter mod distribution utility");
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
  runner.addCommand(MigrateCommand());

  try {
    var parseResults = runner.parse(args);
    if (parseResults.wasParsed("verbose")) {
      Logger.root.level = Level.FINE;
    }

    if (parseResults.wasParsed("version")) {
      print("scatter $version");
      return;
    }

    ConfigManager.loadConfigs();

    await runner.run(args);
  } catch (err) {
    logger.severe("Something went terribly wrong: ", err);
    scatterExit(1);
  }

  scatterExit(0);
}

void scatterExit(int statusCode) {
  Console.showCursor();
  Console.resetAll();
  exit(statusCode);
}

Color levelToColor(Level level) {
  if (level.value > 900) {
    return Color.RED;
  } else if (level.value > 800) {
    return Color.YELLOW;
  } else if (level.value >= 700) {
    return Color.LIGHT_GRAY;
  } else if (level.value < 600) {
    return Color.LIGHT_MAGENTA;
  } else {
    return Color.WHITE;
  }
}
