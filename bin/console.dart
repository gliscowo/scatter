import 'dart:async';
import 'dart:io';

import 'color.dart' as c;
import 'scatter.dart';

final String inputColor = rgbColor(0x0AA1DD);
final String keyColor = rgbColor(0xFCA17D);
const String valueColor = "${c.ansiEscape}0m";

typedef ResponseValidator = FutureOr<bool> Function(String);

void printKeyValuePair(String key, dynamic value, [int expectedKeyLength = 30]) {
  print(formatKeyValuePair(key, value, expectedKeyLength));
  console.resetColorAttributes();
}

String formatKeyValuePair(String key, dynamic value, [int expectedKeyLength = 30]) =>
    "$keyColor$key:${" " * (expectedKeyLength - key.length)}${value is Formattable ? (value).color : valueColor}$value";

String rgbColor(int rgb) => "${c.ansiEscape}38;2;${rgb >> 16};${(rgb >> 8) & 0xFF};${rgb & 0xFF}m";

bool ask(String question, {secret = false}) {
  console.write("$inputColor$question? [y/N] ");
  console.resetColorAttributes();

  return stdin.readLineSync()?.toLowerCase() == "y";
}

String prompt(String message, {bool secret = false}) {
  console.write("$inputColor$message: ");
  console.resetColorAttributes();

  if (!secret) return console.readLine() ?? "";

  stdin.echoMode = false;
  final input = console.readLine();
  stdin.echoMode = true;

  return input ?? "";
}

Future<String> promptValidated(String message, ResponseValidator validator,
    {String? invalidMessage, bool emptyIsValid = false}) async {
  String? response;

  do {
    console.write("$inputColor$message: ");
    console.resetColorAttributes();

    var input = console.readLine()!;
    if ((emptyIsValid && input.trim().isEmpty) || await validator(input)) {
      response = input;
    } else if (invalidMessage != null) {
      logger.warning(invalidMessage);
    }
  } while (response == null);

  return response;
}

abstract class Formattable {
  c.AnsiControlSequence get color;
}
