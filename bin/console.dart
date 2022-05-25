import 'dart:async';
import 'dart:convert';
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

  return readLineAsync().then((value) => value.toLowerCase() == "y");
}

Future<String> prompt(String message, {secret = false}) async {
  Console.adapter.write("$inputColor$message: ");
  Console.resetAll();

  if (secret) stdin.echoMode = false;
  return secret
      ? readLineAsync()
      : readLineAsync().then((value) {
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

    var input = await readLineAsync();
    if ((emptyIsValid && input.trim().isEmpty) || await validator(input)) {
      response = input;
    } else if (invalidMessage != null) {
      logger.warning(invalidMessage);
    }
  } while (response == null);

  return response;
}

Future<String> readLineAsync() => sharedStdIn.transform(utf8.decoder).transform(LineSplitter()).first;

abstract class Colorable {
  Color get color;
}
