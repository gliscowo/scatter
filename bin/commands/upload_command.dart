import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:args/src/arg_results.dart';
import 'package:path/path.dart';
import 'package:pub_semver/pub_semver.dart';

import '../adapters/host_adapter.dart';
import '../chooser.dart';
import '../config/config.dart';
import '../config/data.dart';
import '../console.dart' as util;
import '../scatter.dart';
import '../util.dart';
import 'scatter_command.dart';

class UploadCommand extends ScatterCommand {
  UploadCommand() : super("upload", "Upload the given artifact to all available hosts", arguments: ["mod-id"]) {
    argParser
      ..addFlag(
        "override-game-versions",
        abbr: "o",
        negatable: false,
        help: "Prompt which game versions to use instead of the configured defaults",
      )
      ..addFlag(
        "read-as-file",
        abbr: "f",
        negatable: false,
        help: "Always interpret the second argument as a file, even if an artifact location is defined",
      )
      ..addFlag(
        "confirm",
        abbr: "c",
        negatable: false,
        help: "Whether uploading to each individual platform should be confirmed",
      )
      ..addFlag(
        "confirm-relations",
        abbr: "r",
        negatable: false,
        help: "Ask for each dependency whether it should be declared",
      )
      ..addOption(
        "changelog-mode",
        help: "Override the default changelog mode",
        abbr: "l",
      )
      ..addFlag(
        "preserve-file",
        help: "Preserve the contents of the changelog file in editor mode",
        abbr: "p",
        negatable: false,
      );
  }

  @override
  void execute(ArgResults args) async {
    var mod = ConfigManager.getMod(args.rest.first);
    if (mod == null) throw "Unknown mod id: '${args.rest.first}'";

    var zipDecoder = ZipDecoder();

    String uploadTarget;
    if (args.rest.length < 2) {
      if (!mod.hasArtifactLocation) {
        throw "No artifact location defined, artifact search is unavailable. Usage: 'scatter upload <mod> <version>'";
      }

      var namePattern = mod.artifactFilenamePattern;
      var fileRegex = RegExp(namePattern!.replaceAll("{}", ".+\\"));

      var artifactDir = Directory(mod.artifactDirectory!);
      var files = artifactDir
          .listSync()
          .whereType<File>()
          .where((element) =>
              fileRegex.hasMatch(basename(element.path)) &&
              !element.path.contains("dev") &&
              !element.path.contains("sources"))
          .map((file) => (
                file: file,
                version: basename(file.path)
                    .replaceAll(namePattern.split("{}")[0], "")
                    .replaceAll(namePattern.split("{}")[1], "")
              ))
          .toList()
        ..sort((a, b) => _tryParseVersion(a.version).compareTo(_tryParseVersion(b.version)));

      if (files.isEmpty) throw "No artifacts found";

      logger.info("The following versions were found:");

      uploadTarget = EntryChooser.vertical(
        files,
        selectedEntry: files.length - 1,
        formatter: (p0, idx) =>
            "${files[idx].version} (${extractVersion(zipDecoder.decodeBytes(files[idx].file.readAsBytesSync()), mod.loaders)})",
      ).choose().version;
    } else {
      uploadTarget = args.rest[1];
    }

    File targetFile;
    if (mod.hasArtifactLocation && !args.wasParsed("read-as-file")) {
      var targetFileLocation =
          "${mod.artifactDirectory!}${mod.artifactFilenamePattern!.replaceAll("{}", uploadTarget)}";
      targetFile = File(targetFileLocation);
    } else {
      targetFile = File(uploadTarget);
    }

    if (!targetFile.existsSync()) throw "Unable to find artifact file: '${targetFile.path}'";

    var type = chooseEnum(ReleaseType.values, message: "Release type");

    var gameVersions = ConfigManager.getDefaultVersions();
    if (args.wasParsed("override-game-versions")) {
      var userVersions = (util.prompt("Comma-separated game versions")).split(",");
      gameVersions.clear();
      gameVersions.addAll(userVersions.map((e) => e.trim()));
    } else if (gameVersions.isEmpty) {
      throw "No default versions defined. Use 'scatter config --default-versions' to fix";
    }

    String? artifactVersion;
    var archive = zipDecoder.decodeBytes(targetFile.readAsBytesSync());

    artifactVersion = extractVersion(archive, mod.loaders);

    var parsedGameVersions = <Version>[];
    for (var version in gameVersions) {
      try {
        parsedGameVersions.add(Version.parse(version));
        // ignore: empty_catches
      } catch (err) {}
    }

    String minRequiredGameVersion = parsedGameVersions.isNotEmpty
        ? parsedGameVersions.reduce((value, element) => value < element ? value : element).toString()
        : gameVersions[0].toString();

    var parsedVersion = Version.parse(artifactVersion);
    var displayVersion = Version(parsedVersion.major, parsedVersion.minor, parsedVersion.patch);

    final pattern = mod.versionNamePattern ?? "[{game_version}] {mod_name} - {version}";
    var versionName = pattern
        .replaceAll("{game_version}", minRequiredGameVersion)
        .replaceAll("{mod_name}", mod.displayName)
        .replaceAll("{version}", displayVersion.toString());

    var relations = List.of(mod.relations);

    if (args.wasParsed("confirm-relations")) {
      for (var dep in mod.relations) {
        if (util.ask("Declare dependency '${dep.slug}'")) continue;
        relations.remove(dep);
      }
    }

    ChangelogMode.eraseFile = !args.wasParsed("preserve-file");
    var changelogMode = ConfigManager.get<Config>().defaultChangelogMode;
    if (args.wasParsed("changelog-mode")) {
      var parsedMode = ChangelogMode.values.asNameMap()[args["changelog-mode"]];
      if (parsedMode == null) throw "Unknown changelog mode. Options: editor, prompt, file";

      changelogMode = parsedMode;
    }

    final changelog = await changelogMode.changelogGetter(mod);
    logger.fine("Using changelog: $changelog");

    var spec = UploadSpec(targetFile, versionName, artifactVersion, changelog, type, gameVersions, relations);

    logger.info("A build with following metadata will be published");
    util.printKeyValuePair("Name", versionName, 15);
    util.printKeyValuePair("Version", artifactVersion, 15);
    util.printKeyValuePair("Release Type", type.name, 15);
    if (!util.ask("Proceed")) return;

    for (var platform in HostAdapter.platforms) {
      if (!mod.platformIds.keys.contains(platform.toLowerCase())) continue;

      var adapter = HostAdapter.fromId(platform.toLowerCase());
      if (args.wasParsed("confirm") && !util.ask("Upload to $platform")) continue;

      logger.info("Uploading to $platform");
      await adapter.upload(mod, spec);
    }
  }

  @override
  String get invocation => "${super.invocation} [version]";
}

Version _tryParseVersion(String input) {
  try {
    return Version.parse(input);
  } catch (_) {
    return Version.none;
  }
}

const String changelogPreset = """


// Enter you changelog in this file and save it.
// Lines starting with '//' will be ignored
""";

enum ChangelogMode {
  editor(_openSystemEditor),
  prompt(_readChangelogFromStdin),
  file(_readChangelogFromFile);

  static bool eraseFile = true;

  final Future<String> Function(ModInfo) changelogGetter;

  const ChangelogMode(this.changelogGetter);

  // the most bruh place in scatter
  static Future<String> _openSystemEditor(ModInfo mod) async {
    final changelogFile = File("changelog.md");
    if (changelogFile.existsSync() && eraseFile) {
      changelogFile.writeAsStringSync(changelogPreset, flush: true);
    }

    // we pause the main isolate's event loop here to stop processing stdin events
    // i still don't quite understand why it sometimes just eats them, but it literally makes
    // vim unusable. thus, the vim isolate exists only for waking the main isolate once vim is done
    await Isolate.spawn<(Isolate, Capability)>((message) async {
      final editor = String.fromEnvironment("EDITOR", defaultValue: Platform.isWindows ? "notepad" : "vi");
      await Process.start(editor, ["changelog.md"], mode: ProcessStartMode.inheritStdio)
          .then((value) => value.exitCode);

      message.$1.resume(message.$2);
    }, (Isolate.current, Isolate.current.pause()));

    return _readFile(changelogFile);
  }

  static Future<String> _readChangelogFromStdin(ModInfo mod) async {
    return util.prompt("Changelog");
  }

  static Future<String> _readChangelogFromFile(ModInfo mod) async {
    return _readFile(File(mod.changelogLocation ?? "changelog.md"));
  }

  static Future<String> _readFile(File file) {
    return file.readAsLines().then((lines) {
      lines =
          lines.where((element) => !element.trimLeft().startsWith("//")).skipWhile((value) => value.isEmpty).toList();

      while (lines.isNotEmpty && lines.last.isEmpty) {
        lines.removeLast();
      }

      return lines.join("\n");
    });
  }
}
