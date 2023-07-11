import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_console/dart_console.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

import 'adapters/modrinth_adapter.dart';
import 'color.dart' as c;
import 'commands/add_mod_command.dart';
import 'commands/config_command.dart';
import 'commands/edit_mod_command.dart';
import 'commands/list_game_versions_command.dart';
import 'commands/list_mods_command.dart';
import 'commands/migrate_command.dart';
import 'commands/mod_info_command.dart';
import 'commands/remove_mod_command.dart';
import 'commands/upload_command.dart';
import 'commands/validate_auth_command.dart';
import 'config/config.dart';
import 'console.dart';
import 'version.dart';

final client = Client();
final logger = Logger("scatter");
final console = Console();

void main(List<String> args) async {
  Logger.root.onRecord.listen((event) {
    final message = StringBuffer();
    message.write("${levelToColor(event.level)}${event.level.name.toLowerCase()}${c.reset}: ${event.message}");

    if (event.error != null) {
      if (Logger.root.level <= Level.FINE) {
        message
          ..writeln()
          ..write("${c.red}error: ${c.reset} ${event.error}");

        if (event.stackTrace != null) {
          message
            ..writeln()
            ..write(event.stackTrace);
        } else if (event.error is Error) {
          message
            ..writeln()
            ..write((event.error as Error).stackTrace);
        }
      } else {
        message.write(" (run with -v to see error details)");
      }
    }

    console.writeLine(message);
  });

  var runner = CommandRunner<void>("scatter", "Scatter mod distribution utility");
  runner.argParser.addFlag("verbose", negatable: false, abbr: "v", help: "Print additional debug output");
  runner.argParser.addFlag("version", negatable: false, help: "Print the version and exit");

  runner
    ..addCommand(AddCommand())
    ..addCommand(InfoCommand())
    ..addCommand(ConfigCommand())
    ..addCommand(RemoveCommand())
    ..addCommand(UploadCommand())
    ..addCommand(EditCommand())
    ..addCommand(ListGameVersionsCommand())
    ..addCommand(ListModsCommand())
    ..addCommand(MigrateCommand())
    ..addCommand(ValidateAuthCommand());

  final sigintWatch = ProcessSignal.sigint.watch().listen((event) => console.showCursor());

  try {
    var parseResults = runner.parse(args);
    if (parseResults.wasParsed("version")) {
      logger.info("scatter $packageVersion");
      return;
    }

    if (parseResults.wasParsed("verbose")) {
      Logger.root.level = Level.FINE;
    }

    ConfigManager.loadConfigs();

    await runner.run(args);
  } catch (err, stack) {
    logger.severe(err, err, stack);
    exitCode = 1;
  } finally {
    sigintWatch.cancel();
    console.resetColorAttributes();

    client.close();
    ModrinthAdapter.instance.api.dispose();
  }
}

c.AnsiControlSequence levelToColor(Level level) {
  return switch (level.value) {
    > 900 => c.red,
    > 800 => c.yellow,
    >= 700 => c.brightBlack,
    < 600 => c.brightMagenta,
    _ => c.white
  };
}

Never scatterExit([int code = 1]) {
  client.close();
  console.resetColorAttributes();
  console.showCursor();

  stdin.echo = true;
  exit(code);
}
