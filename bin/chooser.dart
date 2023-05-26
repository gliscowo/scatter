import 'dart:io';
import 'dart:math';

import 'package:dart_console/dart_console.dart';

import 'color.dart' as c;
import 'console.dart';
import 'scatter.dart';

typedef EntryFormatter<T> = String Function(T, int);

E chooseEnum<E extends Enum>(List<E> values, {String? message, E? selected}) {
  return EntryChooser.horizontal(
    values,
    message: message,
    selectedEntry: selected?.index ?? 0,
    formatter: (p0, idx) => p0.name,
  ).choose();
}

abstract class EntryChooser<T> {
  final List<T> _entries;
  final List<ControlCharacter> _bindings;
  final EntryFormatter<T>? _formatter;
  int _selectedEntry = 0;

  EntryChooser(this._entries, this._selectedEntry, this._bindings, {EntryFormatter<T>? formatter})
      : _formatter = formatter;

  factory EntryChooser.vertical(List<T> entries, {int selectedEntry = 0, EntryFormatter<T>? formatter}) {
    return VerticalChooser(entries, selectedEntry, formatter: formatter);
    // return Platform.isWindows ? WindowsChooser(entries, selectedEntry) : VerticalChooser(entries, selectedEntry);
  }

  factory EntryChooser.horizontal(List<T> entries,
      {String? message, int selectedEntry = 0, EntryFormatter<T>? formatter}) {
    return HorizontalChooser(entries, selectedEntry, message, formatter: formatter);

    // return Platform.isWindows
    //     ? WindowsChooser(entries, selectedEntry, message: message)
    //     : HorizontalChooser(entries, selectedEntry, message);
  }

  T choose() {
    stdin.saveStateAndDisableEcho();
    console.hideCursor();

    prepare();
    drawState();
    final cursor = console.cursorPosition;

    while (true) {
      final key = console.readKey();
      if (key.controlChar == ControlCharacter.enter) break;

      if (key.controlChar == _bindings[0]) {
        _selectedEntry = max(0, min(_selectedEntry - 1, _entries.length - 1));
      } else if (key.controlChar == _bindings[1]) {
        _selectedEntry = max(0, min(_selectedEntry + 1, _entries.length - 1));
      }

      drawState();
    }

    console.cursorPosition = cursor;
    console.showCursor();

    stdin.restoreState();
    return _entries[_selectedEntry];
  }

  void prepare();
  void drawState();

  String _format(T t, int idx) {
    return (_formatter ?? (t, idx) => "$t")(t, idx);
  }
}

class VerticalChooser<T> extends EntryChooser<T> {
  VerticalChooser(List<T> entries, int selectedEntry, {EntryFormatter<T>? formatter})
      : super(entries, selectedEntry, [ControlCharacter.arrowUp, ControlCharacter.arrowDown], formatter: formatter);

  @override
  void drawState() {
    for (var i = 0; i < _entries.length; i++) {
      console.cursorUp();
    }

    for (var (i, entry) in _entries.indexed) {
      if (i == _selectedEntry) c.bold.write();
      (entry is Formattable ? entry.color : c.white).write();

      print((i == _selectedEntry ? "→ " : "  ") + _format(_entries[i], i));
      console.resetColorAttributes();
    }
  }

  @override
  void prepare() {
    console.write("\n" * _entries.length);
  }
}

class HorizontalChooser<T> extends EntryChooser<T> {
  String? message;
  Coordinate cursorOrgin;

  HorizontalChooser(List<T> entries, int selectedEntry, this.message, {EntryFormatter<T>? formatter})
      : cursorOrgin = console.cursorPosition!,
        super(entries, selectedEntry, [ControlCharacter.arrowLeft, ControlCharacter.arrowRight], formatter: formatter);

  @override
  void drawState() {
    console.cursorPosition = Coordinate(cursorOrgin.col, cursorOrgin.row + 1);
    console.eraseLine();
    console.cursorUp();

    for (var (i, entry) in _entries.indexed) {
      if (i == _selectedEntry) {
        if (i == _selectedEntry) c.bold.write();
        (entry is Formattable ? entry.color : c.white).write();

        console.cursorDown();
        console.write("↑");
        console.cursorLeft();
        console.cursorUp();
      }

      console.write(_format(_entries[i], i));
      console.resetColorAttributes();
      console.write(" ");
    }

    console.write("\n" * 2);
  }

  @override
  void prepare() {
    if (message != null) {
      console.write("$inputColor$message: ");
      console.resetColorAttributes();
    }

    int column = console.cursorPosition!.col;

    console.write("\n" * 3);
    cursorOrgin = Coordinate(column, console.cursorPosition!.row - 2);
  }
}
