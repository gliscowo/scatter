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

  if (!secret) return readLine();

  stdin.echo = false;
  final input = stdin.readLineSync();
  stdin.echo = true;

  return input ?? "";
}

Future<String> promptValidated(String message, ResponseValidator validator,
    {String? invalidMessage, bool emptyIsValid = false}) async {
  String? response;

  do {
    console.write("$inputColor$message: ");
    console.resetColorAttributes();

    var input = readLine();
    if ((emptyIsValid && input.trim().isEmpty) || await validator(input)) {
      response = input;
    } else if (invalidMessage != null) {
      logger.warning(invalidMessage);
    }
  } while (response == null);

  return response;
}

String readLine() {
  final input = console.readLine(cancelOnBreak: true);
  if (input == null) {
    scatterExit(1);
  }

  return input;
}

abstract class Formattable {
  c.AnsiControlSequence get color;
}

extension ModeExtensions on Stdin {
  static bool _echo = stdin.echoMode;
  static bool _line = stdin.lineMode;

  void saveStateAndDisableEcho() {
    _echo = echoMode;
    _line = lineMode;

    echo = false;
    line = false;
  }

  void restoreState() {
    line = _line;
    echo = _echo;
  }

  set echo(bool echo) {
    if (echoMode == echo) return;

    // for windows reasons we also have to set line mode
    // to true when enabling echo. thank you microsoft
    if (Platform.isWindows) {
      line = true;
    }

    echoMode = echo;
  }

  set line(bool line) {
    if (lineMode == line) return;
    lineMode = line;
  }
}
