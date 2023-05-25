import 'dart:async';
import 'dart:io';

import 'package:console/console.dart';
import 'package:io/io.dart';

import 'scatter.dart';

final String inputColor = color(0x0AA1DD);
final String keyColor = color(0xFCA17D);
const String valueColor = "${Console.ANSI_ESCAPE}0m";

typedef ResponseValidator = FutureOr<bool> Function(String);

void printKeyValuePair(String key, dynamic value, [expectedKeyLength = 30]) {
  print(formatKeyValuePair(key, value, expectedKeyLength));
  Console.resetAll();
}

String formatKeyValuePair(String key, dynamic value, [expectedKeyLength = 30]) =>
    "$keyColor$key:${" " * (expectedKeyLength - key.length)}${value is Colorable ? (value).color : valueColor}$value";

String color(int rgb) => "${Console.ANSI_ESCAPE}38;2;${rgb >> 16};${(rgb >> 8) & 0xFF};${rgb & 0xFF}m";

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
