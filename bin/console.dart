import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:console/console.dart';

import 'scatter.dart';

const Color inputColor = Color.GOLD;
const Color keyColor = Color.BLUE;
const Color valueColor = Color.LIGHT_GRAY;

typedef ResponseValidator = FutureOr<bool> Function(String);
typedef EntryFormatter<T> = String Function(T);

Future<T> chooseEnum<T extends Enum>(List<T> values, {String? message, T? selected}) async {
  return (EntryChooser.horizontal(values, message: message, selectedEntry: selected != null ? selected.index : 0)
        ..formatter = (p0) => p0.name)
      .choose();
}

abstract class EntryChooser<T> {
  final List<T> _entries;
  final List<String> _bindings;
  EntryFormatter<T>? formatter;
  int _selectedEntry = 0;

  EntryChooser(this._entries, this._selectedEntry, this._bindings);

  factory EntryChooser.vertical(List<T> entries, {int selectedEntry = 0}) {
    return VerticalChooser(entries, selectedEntry);
  }

  factory EntryChooser.horizontal(List<T> entries, {String? message, int selectedEntry = 0}) {
    return HorizontalChooser(entries, selectedEntry, message);
  }

  Future<T> choose() async {
    StdinModes.save();
    stdin.echoMode = false;
    stdin.lineMode = false;
    Console.hideCursor();
    Console.resetAll();

    prepare();
    drawState();
    Console.saveCursor();

    final upSub = inputBytes.where((event) => event == _bindings[0]).listen((event) {
      _selectedEntry = max(0, min(_selectedEntry - 1, _entries.length - 1));
      drawState();
    });

    final downSub = inputBytes.where((event) => event == _bindings[1]).listen((event) {
      _selectedEntry = max(0, min(_selectedEntry + 1, _entries.length - 1));
      drawState();
    });

    await inputBytes.where((event) => event == "\u000a").first;
    await Future.wait([upSub.cancel(), downSub.cancel()]);

    Console.restoreCursor();
    Console.showCursor();
    StdinModes.restore();
    return _entries[_selectedEntry];
  }

  void prepare();
  void drawState();

  String _format(T t) {
    return (formatter ?? (t) => "$t")(t);
  }
}

class VerticalChooser<T> extends EntryChooser<T> {
  VerticalChooser(List<T> entries, int selectedEntry)
      : super(entries, selectedEntry, ["${Console.ANSI_ESCAPE}A", "${Console.ANSI_ESCAPE}B"]);

  @override
  void drawState() {
    Console.moveCursorUp(_entries.length);

    for (int i = 0; i < _entries.length; i++) {
      if (i == _selectedEntry) Console.setBold(true);
      print((i == _selectedEntry ? "→ " : "  ") + _format(_entries[i]));
      Console.resetAll();
    }
  }

  @override
  void prepare() {
    Console.adapter.write("\n" * _entries.length);
  }
}

class HorizontalChooser<T> extends EntryChooser<T> {
  String? message;
  CursorPosition cursorOrgin;

  HorizontalChooser(List<T> entries, int selectedEntry, this.message)
      : cursorOrgin = Console.getCursorPosition(),
        super(entries, selectedEntry, ["${Console.ANSI_ESCAPE}D", "${Console.ANSI_ESCAPE}C"]);

  @override
  void drawState() {
    Console.moveCursor(column: cursorOrgin.column, row: cursorOrgin.row - 1);
    Console.writeANSI("2K");
    Console.moveCursorUp();

    for (int i = 0; i < _entries.length; i++) {
      if (i == _selectedEntry) {
        final entry = _entries[i];
        (entry is Colorable ? entry.color : Color.WHITE).makeCurrent();

        Console.moveCursorDown();
        Console.adapter.write("↑");
        Console.moveCursorBack();
        Console.moveCursorUp();
      }

      Console.adapter.write(_format(_entries[i]));
      Console.resetAll();
      Console.adapter.write(" ");
    }

    Console.adapter.write("\n" * 2);
  }

  @override
  void prepare() {
    if (message != null) {
      Console.adapter.write("$inputColor$message: ");
      Console.resetAll();
    }

    cursorOrgin = Console.getCursorPosition();
    Console.adapter.write("\n" * 2);
  }
}

void printKeyValuePair(String key, dynamic value, [expectedKeyLength = 30]) {
  stdout.write("$keyColor$key:${" " * (expectedKeyLength - key.length)}");
  print("${value is Colorable ? (value).color : valueColor}$value");
  Console.resetAll();
}

Future<bool> ask(String question, {secret = false}) async {
  inputColor.makeCurrent();
  Console.adapter.write("$question? [Y/n] ");
  Console.resetAll();

  return inputBytes.transform(LineSplitter()).first.then((value) => value.toLowerCase() == "y");
}

Future<String> prompt(String message, {secret = false}) async {
  inputColor.makeCurrent();
  Console.adapter.write("$message: ");
  Console.resetAll();

  return inputBytes.transform(LineSplitter()).first;
}

Future<String> promptValidated(String message, ResponseValidator validator,
    {String invalidMessage = "", bool emptyIsValid = false}) async {
  String response;
  bool valid = false;

  do {
    inputColor.makeCurrent();
    Console.adapter.write("$message: ");
    var future = inputBytes.transform(LineSplitter()).first;
    Console.resetAll();

    response = await future;
    if (!(valid = (emptyIsValid && response.trim().isEmpty) || await validator(response)) &&
        invalidMessage.isNotEmpty) {
      logger.info(invalidMessage);
    }
  } while (!valid);

  return Future.value(response);
}

class StdinModes {
  static bool echo = stdin.echoMode;
  static bool line = stdin.lineMode;

  static save() {
    echo = stdin.echoMode;
    line = stdin.lineMode;
  }

  static restore() {
    stdin.echoMode = echo;
    stdin.lineMode = line;
  }
}

abstract class Colorable {
  Color get color;
}
