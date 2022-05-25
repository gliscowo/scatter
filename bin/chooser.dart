import 'dart:io';
import 'dart:math';

import 'package:console/console.dart';

import 'console.dart';
import 'scatter.dart';

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
    return Platform.isWindows ? WindowsChooser(entries, selectedEntry) : VerticalChooser(entries, selectedEntry);
  }

  factory EntryChooser.horizontal(List<T> entries, {String? message, int selectedEntry = 0}) {
    return Platform.isWindows
        ? WindowsChooser(entries, selectedEntry, message: message)
        : HorizontalChooser(entries, selectedEntry, message);
  }

  Future<T> choose() async {
    _StdinModes.save();
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
    _StdinModes.restore();
    return _entries[_selectedEntry];
  }

  void prepare();
  void drawState();

  String _format(T t) {
    return (formatter ?? (t) => "$t")(t);
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
      print("  [$i] ${_format(_entries[i])}");
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
    Console.moveCursor(column: cursorOrgin.column, row: cursorOrgin.row + 1);
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

    int column = Console.getCursorPosition().column;

    Console.adapter.write("\n" * 2);
    cursorOrgin = CursorPosition(column, Console.getCursorPosition().row - 2);
  }
}

class _StdinModes {
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
