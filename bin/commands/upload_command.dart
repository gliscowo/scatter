import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:args/src/arg_results.dart';
import 'package:path/path.dart';
import 'package:version/version.dart';

import '../adapters/host_adapter.dart';
import '../config/config.dart';
import '../config/data.dart';
import '../console.dart' as util;
import '../scatter.dart';
import '../util.dart';
import 'scatter_command.dart';

class UploadCommand extends ScatterCommand {
  UploadCommand() : super("upload", "Upload the given artifact to all available hosts") {
    argParser.addFlag("override-game-versions",
        abbr: "o", negatable: false, help: "Prompt which game versions to use instead of using the default ones");
    argParser.addFlag("read-as-file",
        abbr: "f",
        negatable: false,
        help: "Always interpret the second argument as a file, even if an artifact location is defined");
    argParser.addFlag("confirm",
        abbr: "c", negatable: false, help: "Whether uploading to each individual platform should be confirmed");
    argParser.addFlag("confirm-relations",
        abbr: "r", negatable: false, help: "Ask for each dependency whether it should be declared");
    argParser.addOption("changelog-mode", help: "Override the default changelog mode", abbr: "l");
  }

  @override
  void execute(ArgResults args) async {
    if (args.rest.isEmpty) throw "Missing mod id. Usage: 'scatter upload <mod> [version]'";

    var mod = ConfigManager.getMod(args.rest[0]);
    if (mod == null) throw "Unknown mod id: '${args.rest[0]}'";

    var zipDecoder = ZipDecoder();
    var modloader = getEnum(Modloader.values, mod.modloader);

    String uploadTarget;
    if (args.rest.length < 2) {
      if (!mod.artifactLocationDefined()) {
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
          .toList();

      if (files.isEmpty) throw "No artifacts found";

      var versions = files
          .map((e) =>
              basename(e.path).replaceAll(namePattern.split("{}")[0], "").replaceAll(namePattern.split("{}")[1], ""))
          .toList()
        ..sort();

      logger.info("The following versions were found:");

      uploadTarget = await (util.EntryChooser.vertical(versions, selectedEntry: versions.length - 1)
            ..formatter = (p0) {
              int idx = versions.indexOf(p0);
              return "${versions[idx]} (${extractVersion(zipDecoder.decodeBytes(files[idx].readAsBytesSync()), modloader)})";
            })
          .choose();
    } else {
      uploadTarget = args.rest[1];
    }

    File targetFile;
    if (mod.artifactLocationDefined() && !args.wasParsed("read-as-file")) {
      var targetFileLocation =
          "${mod.artifactDirectory!}${mod.artifactFilenamePattern!.replaceAll("{}", uploadTarget)}";
      targetFile = File(targetFileLocation);
    } else {
      targetFile = File(uploadTarget);
    }

    if (!targetFile.existsSync()) throw "Unable to find artifact file: '${targetFile.path}'";

    var mode = ConfigManager.get<Config>().defaultChangelogMode;
    if (args.wasParsed("changelog-mode")) {
      var parsedMode = ChangelogMode.values.asNameMap()[args["changelog-mode"]];
      if (parsedMode == null) throw "Unknown changelog mode. Options: editor, prompt, file";

      mode = parsedMode;
    }

    final changelog = await mode.changelogGetter();
    logger.fine("Using changelog: $changelog");

    var type = await (util.EntryChooser.horizontal(ReleaseType.values, message: "Release type")
          ..formatter = (p0) => p0.name)
        .choose();

    var gameVersions = ConfigManager.getDefaultVersions();
    if (args.wasParsed("override-game-versions")) {
      var userVersions = (await util.prompt("Comma-separated game versions")).split(",");
      gameVersions.clear();
      gameVersions.addAll(userVersions.map((e) => e.trim()));
    } else if (gameVersions.isEmpty) {
      throw "No default versions defined. Use 'scatter config --default-versions' to fix";
    }

    String? artifactVersion;
    var archive = zipDecoder.decodeBytes(targetFile.readAsBytesSync());

    artifactVersion = extractVersion(archive, modloader);

    var parsedGameVersions = <Version>[];
    for (var version in gameVersions) {
      try {
        parsedGameVersions.add(Version.parse(version));
        // ignore: empty_catches
      } catch (err) {}
    }

    String minRequiredGameVersion = parsedGameVersions.isNotEmpty
        ? parsedGameVersions.reduce((value, element) => value < element ? value : element).toFancyString()
        : gameVersions[0].toString();

    var parsedVersion = Version.parse(artifactVersion);
    var displayVersion = Version(parsedVersion.major, parsedVersion.minor, parsedVersion.patch);

    var versionName =
        "[$minRequiredGameVersion${parsedGameVersions.length > 1 ? "+" : ""}] ${mod.displayName} - $displayVersion";

    var relations = List.of(mod.relations);

    if (args.wasParsed("confirm-relations")) {
      for (var dep in mod.relations) {
        if (await util.ask("Declare dependency '${dep.slug}'")) continue;
        relations.remove(dep);
      }
    }

    var spec = UploadSpec(targetFile, versionName, artifactVersion, changelog, type, gameVersions, relations);

    logger.info("A build with following metadata will be published");
    util.printKeyValuePair("Name", versionName, 15);
    util.printKeyValuePair("Version", artifactVersion, 15);
    util.printKeyValuePair("Release Type", getName(type), 15);
    if (!await util.ask("Proceed")) return;

    for (var platform in HostAdapter.platforms) {
      if (!mod.platformIds.keys.contains(platform.toLowerCase())) continue;

      var adapter = HostAdapter.fromId(platform.toLowerCase());
      if (args.wasParsed("confirm") && !await util.ask("Upload to $platform")) continue;

      logger.info("Uploading to $platform");
      await adapter.upload(mod, spec);
    }
  }
}

enum ChangelogMode {
  editor(_openSystemEditor),
  prompt(_readChangelogFromStdin),
  file(_readChangelogFromFile);

  final Future<String> Function() changelogGetter;

  const ChangelogMode(this.changelogGetter);

  static Future<String> _openSystemEditor() async {
    final changelogFile = File("changelog.md")..writeAsStringSync("");

    final editor = String.fromEnvironment("EDITOR", defaultValue: Platform.isWindows ? "notepad" : "vi");
    await Process.start(editor, ["changelog.md"], mode: ProcessStartMode.inheritStdio)
        .then((process) => process.exitCode);

    return changelogFile.readAsString();
  }

  static Future<String> _readChangelogFromStdin() async {
    return util.prompt("Changelog");
  }

  static Future<String> _readChangelogFromFile() async {
    return File("changelog.md").readAsString();
  }
}
