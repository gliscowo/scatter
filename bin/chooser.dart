import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:console/console.dart';
import 'package:io/io.dart';

import 'console.dart';
import 'scatter.dart';

typedef EntryFormatter<T> = String Function(T, int);

Future<T> chooseEnum<T extends Enum>(List<T> values, {String? message, T? selected}) async {
  return (EntryChooser.horizontal(values, message: message, selectedEntry: selected != null ? selected.index : 0)
        ..formatter = (p0, idx) => p0.name)
      .choose();
}

abstract class EntryChooser<T> {
  final List<T> _entries;
  final List<String> _bindings;
  EntryFormatter<T>? formatter;
  int _selectedEntry = 0;

  EntryChooser(this._entries, this._selectedEntry, this._bindings);

  factory EntryChooser.vertical(List<T> entries, {int selectedEntry = 0}) {
    return Platform.isWindows ? WindowsChooser(entries, selectedEntry) : VerticalChooser(entries, selectedEntry);
  }

  factory EntryChooser.horizontal(List<T> entries, {String? message, int selectedEntry = 0}) {
    return Platform.isWindows
        ? WindowsChooser(entries, selectedEntry, message: message)
        : HorizontalChooser(entries, selectedEntry, message);
  }

  Future<T> choose() async {
    stdin.saveStateAndDisableEcho();
    Console.resetAll();
    Console.writeANSI("?25l"); // \x1b[?25l - hide cursor

    prepare();
    drawState();
    Console.saveCursor();

    final inputChars = sharedStdIn.transform(utf8.decoder).takeWhile((element) => element != "\u000a");

    await for (var key in inputChars) {
      if (key == _bindings[0]) {
        _selectedEntry = max(0, min(_selectedEntry - 1, _entries.length - 1));
      } else if (key == _bindings[1]) {
        _selectedEntry = max(0, min(_selectedEntry + 1, _entries.length - 1));
      }
      drawState();
    }

    Console.restoreCursor();
    Console.showCursor();
    stdin.restoreState();
    return _entries[_selectedEntry];
  }

  void prepare();
  void drawState();

  String _format(T t, int idx) {
    return (formatter ?? (t, idx) => "$t")(t, idx);
  }
}

class WindowsChooser<T> extends EntryChooser<T> {
  String? message;
  WindowsChooser(List<T> entries, int selectedEntry, {this.message}) : super(entries, selectedEntry, ["", ""]);

  @override
  Future<T> choose() async {
    if (message != null) {
      print("$inputColor$message: ");
      Console.resetAll();
    }

    for (int i = 0; i < _entries.length; i++) {
      print("  [$i] ${_format(_entries[i], i)}");
      Console.resetAll();
    }

    stdout.write("${inputColor}Selection: ");
    int selectedIndex = -1;
    do {
      final input = int.tryParse(await readLineAsync());
      if (input != null && input > -1 && input < _entries.length) {
        selectedIndex = input;
      } else {
        logger.warning("Invalid selection");
        stdout.write("${inputColor}Selection: ");
      }
    } while (selectedIndex == -1);

    return _entries[selectedIndex];
  }

  @override
  void drawState() {}

  @override
  void prepare() {}
}

class VerticalChooser<T> extends EntryChooser<T> {
  VerticalChooser(List<T> entries, int selectedEntry)
      : super(entries, selectedEntry, ["${Console.ANSI_ESCAPE}A", "${Console.ANSI_ESCAPE}B"]);

  @override
  void drawState() {
    Console.moveCursorUp(_entries.length);

    for (int i = 0; i < _entries.length; i++) {
      if (i == _selectedEntry) Console.setBold(true);
      print((i == _selectedEntry ? "→ " : "  ") + _format(_entries[i], i));
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
    Console.moveCursor(column: cursorOrgin.column, row: cursorOrgin.row + 1);
    Console.writeANSI("2K"); // \x1b[nK - clear line : n = 2 - clear entire line
    Console.moveCursorUp();

    for (int i = 0; i < _entries.length; i++) {
      if (i == _selectedEntry) {
        final entry = _entries[i];

        if (i == _selectedEntry) Console.setBold(true);
        (entry is Colorable ? entry.color : Color.WHITE).makeCurrent();

        Console.moveCursorDown();
        Console.adapter.write("↑");
        Console.moveCursorBack();
        Console.moveCursorUp();
      }

      Console.adapter.write(_format(_entries[i], i));
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

    int column = Console.getCursorPosition().column;

    Console.adapter.write("\n" * 2);
    cursorOrgin = CursorPosition(column, Console.getCursorPosition().row - 2);
  }
}

extension SaveModes on Stdin {
  static bool _echo = stdin.echoMode;
  static bool _line = stdin.lineMode;

  void saveStateAndDisableEcho() {
    _echo = echoMode;
    _line = lineMode;

    echoMode = false;
    lineMode = false;
  }

  void restoreState() {
    stdin.echoMode = _echo;
    stdin.lineMode = _line;
  }
}
