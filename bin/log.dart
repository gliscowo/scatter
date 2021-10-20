import 'dart:io';

import 'package:console/console.dart';

const Color questionColor = Color.BLUE;
const Color promptColor = Color.LIGHT_CYAN;

void info(dynamic message, {bool frame = false}) {
  if (frame) print("");
  stdout.write("${Color.BLUE}[${Color.WHITE}INFO${Color.BLUE}] ");
  Console.resetAll();

  print(message);
  if (frame) print("");
}

void error(dynamic error, {dynamic message}) {
  stdout.write("${Color.DARK_RED}[${Color.WHITE}ERROR${Color.DARK_RED}] ");
  if (message != null) print("$message\n");

  print(error);

  Console.resetAll();
}

Future<bool> ask(String question) async {
  questionColor.makeCurrent();
  var future = Prompter("$question? ").ask();

  Color.GRAY.makeCurrent();
  stdout.write("[Y/n] ");

  Console.resetAll();
  return future;
}

Future<String> prompt(String message) async {
  promptColor.makeCurrent();
  var future = Prompter("$message: ").prompt();

  Console.resetAll();
  return future;
}

Future<String> promptValidated(String message, ResponseChecker validator, {String invalidMessage = ""}) async {
  var prompter = Prompter("$message: ");
  String response;

  do {
    promptColor.makeCurrent();
    var future = prompter.prompt();
    Console.resetAll();

    response = await future;
    if (!validator(response) && invalidMessage.isNotEmpty) info(invalidMessage, frame: true);
  } while (!validator(response));

  return Future.value(response);
}
