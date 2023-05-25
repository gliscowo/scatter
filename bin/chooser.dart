import 'dart:io';
import 'dart:math';

import 'package:dart_console/dart_console.dart';

import 'color.dart' as c;
import 'console.dart';
import 'scatter.dart';

typedef EntryFormatter<T> = String Function(T, int);

T chooseEnum<T extends Enum>(List<T> values, {String? message, T? selected}) {
  return (EntryChooser.horizontal(values, message: message, selectedEntry: selected != null ? selected.index : 0)
        ..formatter = (p0, idx) => p0.name)
      .choose();
}

abstract class EntryChooser<T> {
  final List<T> _entries;
  final List<ControlCharacter> _bindings;
  EntryFormatter<T>? formatter;
  int _selectedEntry = 0;

  EntryChooser(this._entries, this._selectedEntry, this._bindings);

  factory EntryChooser.vertical(List<T> entries, {int selectedEntry = 0}) {
    return VerticalChooser(entries, selectedEntry);
    // return Platform.isWindows ? WindowsChooser(entries, selectedEntry) : VerticalChooser(entries, selectedEntry);
  }

  factory EntryChooser.horizontal(List<T> entries, {String? message, int selectedEntry = 0}) {
    return HorizontalChooser(entries, selectedEntry, message);

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
    return (formatter ?? (t, idx) => "$t")(t, idx);
  }
}

// class WindowsChooser<T> extends EntryChooser<T> {
//   String? message;
//   WindowsChooser(List<T> entries, int selectedEntry, {this.message}) : super(entries, selectedEntry, ["", ""]);

//   @override
//   Future<T> choose() async {
//     if (message != null) {
//       print("$inputColor$message: ");
//       Console.resetAll();
//     }

//     for (int i = 0; i < _entries.length; i++) {
//       print("  [$i] ${_format(_entries[i], i)}");
//       Console.resetAll();
//     }

//     stdout.write("${inputColor}Selection: ");
//     int selectedIndex = -1;
//     do {
//       final input = int.tryParse(await sharedStdIn.nextLine());
//       if (input != null && input > -1 && input < _entries.length) {
//         selectedIndex = input;
//       } else {
//         logger.warning("Invalid selection");
//         stdout.write("${inputColor}Selection: ");
//       }
//     } while (selectedIndex == -1);

//     return _entries[selectedIndex];
//   }

//   @override
//   void drawState() {}

//   @override
//   void prepare() {}
// }

class VerticalChooser<T> extends EntryChooser<T> {
  VerticalChooser(List<T> entries, int selectedEntry)
      : super(entries, selectedEntry, [ControlCharacter.arrowUp, ControlCharacter.arrowDown]);

  @override
  void drawState() {
    for (var i = 0; i < _entries.length; i++) {
      console.cursorUp();
    }

    for (int i = 0; i < _entries.length; i++) {
      if (i == _selectedEntry) c.bold.write();
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

  HorizontalChooser(List<T> entries, int selectedEntry, this.message)
      : cursorOrgin = console.cursorPosition!,
        super(entries, selectedEntry, [ControlCharacter.arrowLeft, ControlCharacter.arrowRight]);

  @override
  void drawState() {
    console.cursorPosition = Coordinate(cursorOrgin.col, cursorOrgin.row + 1);
    console.eraseLine();
    console.cursorUp();

    for (int i = 0; i < _entries.length; i++) {
      if (i == _selectedEntry) {
        final entry = _entries[i];

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

    console.write("\n" * 2);
    cursorOrgin = Coordinate(column, console.cursorPosition!.row - 2);
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
