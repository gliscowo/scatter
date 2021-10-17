import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:console/console.dart';
import 'package:http/http.dart' as http;

import 'commands/list_game_versions_command.dart';
import 'commands/upload_command.dart';

const String version = "0.1";

final client = http.Client();

void main(List<String> args) async {
  Console.init();
  print("");

  var runner = CommandRunner("scatter", "Scatter mod distribution utility");
  runner.argParser.addFlag("debug", negatable: false);
  runner.argParser.addFlag("version", negatable: false, help: "Print the version and exit");

  runner.addCommand(ListGameVersionsCommand());
  runner.addCommand(UploadCommand());

  var parseResults = runner.parse(args);
  if (parseResults.wasParsed("version")) {
    print("scatter $version");
    return;
  }

  await runner.run(args);

  Console.showCursor();
  Console.resetAll();

  exit(0);
}
