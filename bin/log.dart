import 'dart:async';
import 'dart:io';

import 'package:console/console.dart';

import 'scatter.dart';

const Color questionColor = Color.BLUE;
const Color promptColor = Color.LIGHT_CYAN;

typedef ResponseValidator = FutureOr<bool> Function(String);

void debug(dynamic message) {
  if (!verbose) return;
  stdout.write("${Color.MAGENTA}[${Color.WHITE}DEBUG${Color.MAGENTA}] ");
  Console.resetAll();

  print(message);
}

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
  if (error is Error) print(error.stackTrace);

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

Future<String> promptValidated(String message, ResponseValidator validator, {String invalidMessage = "", bool emptyIsValid = false}) async {
  var prompter = Prompter("$message: ");
  String response;
  bool valid = false;

  do {
    promptColor.makeCurrent();
    var future = prompter.prompt();
    Console.resetAll();

    response = await future;
    if (!(valid = (emptyIsValid && response.trim().isEmpty) || await validator(response)) && invalidMessage.isNotEmpty) info(invalidMessage, frame: true);
  } while (!valid);

  return Future.value(response);
}
