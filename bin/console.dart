import 'dart:async';
import 'dart:io';

import 'package:console/console.dart';

import 'scatter.dart';

const Color questionColor = Color.BLUE;
const Color keyColor = Color.BLUE;
const Color valueColor = Color.LIGHT_GRAY;

typedef ResponseValidator = FutureOr<bool> Function(String);

void printKeyValuePair(String key, dynamic value, [expectedKeyLength = 30]) {
  stdout.write("$keyColor$key:${" " * (expectedKeyLength - key.length)}");
  print("$valueColor$value");
  Console.resetAll();
}

Future<bool> ask(String question) async {
  questionColor.makeCurrent();
  final future = Prompter("$question? ").ask();

  Color.LIGHT_GRAY.makeCurrent();
  stdout.write("[Y/n] ");

  Console.resetAll();
  return future;
}

Future<String> prompt(String message, {secret = false}) async {
  questionColor.makeCurrent();
  var future = Prompter("$message: ", secret: secret).prompt();

  Console.resetAll();
  return future;
}

Future<String> promptValidated(String message, ResponseValidator validator,
    {String invalidMessage = "", bool emptyIsValid = false}) async {
  var prompter = Prompter("$message: ");
  String response;
  bool valid = false;

  do {
    questionColor.makeCurrent();
    var future = prompter.prompt();
    Console.resetAll();

    response = await future;
    if (!(valid = (emptyIsValid && response.trim().isEmpty) || await validator(response)) &&
        invalidMessage.isNotEmpty) {
      logger.info(invalidMessage);
    }
  } while (!valid);

  return Future.value(response);
}
