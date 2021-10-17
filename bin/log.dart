import 'dart:io';

import 'package:console/console.dart';

void info(dynamic message) {
  Color.BLUE.makeCurrent();
  _print(message);
  Console.resetTextColor();
}

void error(dynamic message, dynamic error) {
  stdout.write("- $message: ");
  Color.DARK_RED.makeCurrent();
  print(error);
  Console.resetTextColor();
}

Future<bool> prompt(String message) async {
  Color.DARK_BLUE.makeCurrent();
  var future = Prompter("$message? ").ask();

  Color.GRAY.makeCurrent();
  stdout.write("[Y/n] ");

  Console.resetTextColor();
  return future;
}

void _print(dynamic message) {
  print("- $message");
}
