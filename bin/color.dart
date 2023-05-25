import 'scatter.dart';

const ansiEscape = "\x1b[";

const black = AnsiControlSequence("30m");
const red = AnsiControlSequence("31m");
const green = AnsiControlSequence("32m");
const yellow = AnsiControlSequence("33m");
const blue = AnsiControlSequence("34m");
const magenta = AnsiControlSequence("35m");
const cyan = AnsiControlSequence("36m");
const white = AnsiControlSequence("37m");
const brightBlack = AnsiControlSequence("90m");
const brightRed = AnsiControlSequence("91m");
const brightGreen = AnsiControlSequence("92m");
const brightYellow = AnsiControlSequence("93m");
const brightBlue = AnsiControlSequence("94m");
const brightMagenta = AnsiControlSequence("95m");
const brightCyan = AnsiControlSequence("96m");
const brightWhite = AnsiControlSequence("97m");

const bold = AnsiControlSequence("1m");

const reset = AnsiControlSequence("0m");

final class AnsiControlSequence {
  final String code;
  const AnsiControlSequence(String color) : code = "$ansiEscape$color";

  void write() => console.write(code);

  @override
  String toString() => code;
}
