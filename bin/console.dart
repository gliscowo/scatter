import 'dart:async';
import 'dart:io';

import 'package:console/console.dart';
import 'package:io/io.dart';

import 'scatter.dart';

const Color inputColor = Color.DARK_BLUE;
const Color keyColor = Color.BLUE;
const Color valueColor = Color.LIGHT_GRAY;

typedef ResponseValidator = FutureOr<bool> Function(String);

void printKeyValuePair(String key, dynamic value, [expectedKeyLength = 30]) {
  stdout.write("$keyColor$key:${" " * (expectedKeyLength - key.length)}");
  print("${value is Colorable ? (value).color : valueColor}$value");
  Console.resetAll();
}

Future<bool> ask(String question, {secret = false}) async {
  Console.adapter.write("$inputColor$question? [Y/n] ");
  Console.resetAll();

  return sharedStdIn.nextLine().then((value) => value.toLowerCase().trim() == "y");
}

Future<String> prompt(String message, {secret = false}) async {
  Console.adapter.write("$inputColor$message: ");
  Console.resetAll();

  if (secret) stdin.echoMode = false;
  return secret
      ? sharedStdIn.nextLine()
      : sharedStdIn.nextLine().then((value) {
          stdin.echoMode = true;
          return value;
        });
}

Future<String> promptValidated(String message, ResponseValidator validator,
    {String? invalidMessage, bool emptyIsValid = false}) async {
  String? response;

  do {
    Console.adapter.write("$inputColor$message: ");
    Console.resetAll();

    var input = await sharedStdIn.nextLine();
    if ((emptyIsValid && input.trim().isEmpty) || await validator(input)) {
      response = input;
    } else if (invalidMessage != null) {
      logger.warning(invalidMessage);
    }
  } while (response == null);

  return response;
}

abstract class Colorable {
  Color get color;
}
