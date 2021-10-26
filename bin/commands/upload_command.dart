import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:args/src/arg_results.dart';
import 'package:path/path.dart';
import 'package:toml/toml.dart';
import 'package:version/version.dart';

import '../adapters/host_adapter.dart';
import '../config/config.dart';
import '../log.dart';
import '../util.dart';
import 'scatter_command.dart';

class UploadCommand extends ScatterCommand {
  @override
  final String description = "Upload the given artifact to all available hosts";

  @override
  final String name = "upload";

  UploadCommand() {
    argParser.addFlag("override-game-versions", abbr: "o", negatable: false, help: "Prompt which game versions to use instead of using the default ones");
    argParser.addFlag("read-as-file",
        abbr: "f", negatable: false, help: "Always interpret the second argument as a file, even if an artifact location is defined");
    argParser.addFlag("confirm", abbr: "c", negatable: false, help: "Whether uploading to each individual platform should be confirmed");
  }

  @override
  void execute(ArgResults args) async {
    if (args.rest.isEmpty) throw "Missing mod id. Usage: 'scatter upload <mod> [version]'";

    var mod = ConfigManager.getMod(args.rest[0]);
    if (mod == null) throw "Unknown mod id: '${args.rest[0]}'";

    var uploadTarget;
    if (args.rest.length < 2) {
      if (!mod.artifactLocationDefined()) throw "No artifact location defined, artifact search is unavailable. Usage: 'scatter upload <mod> <version>'";

      var namePattern = mod.artifact_filename_pattern;
      var fileRegex = RegExp(namePattern!.replaceAll("{}", ".+\\"));

      var artifactDir = Directory(mod.artifact_directory!);
      var files = artifactDir
          .listSync()
          .where((element) => fileRegex.hasMatch(basename(element.path)) && !element.path.contains("dev") && !element.path.contains("sources"));

      if (files.isEmpty) throw "No artifacts found";

      var versions = files.map((e) => basename(e.path).replaceAll(namePattern.split("{}")[0], "").replaceAll(namePattern.split("{}")[1], "")).toList();

      int idx = 0;
      info("The following versions were found:");
      for (var version in versions) {
        print("[$idx] $version");
        idx++;
      }

      var uploadIndex = int.parse(await prompt("Number of version to upload"));
      if (uploadIndex > versions.length - 1) throw "Invalid version index";

      uploadTarget = versions[uploadIndex];
    } else {
      uploadTarget = args.rest[1];
    }

    File targetFile;
    if (mod.artifactLocationDefined() && !args.wasParsed("read-as-file")) {
      var targetFileLocation = "${mod.artifact_directory!}${mod.artifact_filename_pattern!.replaceAll("{}", uploadTarget)}";
      targetFile = File(targetFileLocation);
    } else {
      targetFile = File(uploadTarget);
    }

    if (!targetFile.existsSync()) throw "Unable to find artifact file: '${targetFile.path}'";

    var desc = await prompt("Changelog");
    var type = getEnum(ReleaseType.values, await promptValidated("Release Type", enumMatcher(ReleaseType.values), invalidMessage: "Invalid release type"));

    var gameVersions = ConfigManager.getDefaultVersions();
    if (args.wasParsed("override-game-versions")) {
      var userVersions = (await prompt("Comma-separated game versions")).split(",");
      gameVersions.clear();
      gameVersions.addAll(userVersions.map((e) => e.trim()));
    } else if (gameVersions.isEmpty) {
      throw "No default versions defined. Use 'scatter config --default-versions' to fix";
    }

    String? artifactVersion;
    var archive = ZipDecoder().decodeBytes(targetFile.readAsBytesSync());

    if (mod.modloader == "fabric") {
      var fmjFile = archive.findFile("fabric.mod.json");
      if (fmjFile == null) throw "The provided artifact is not a fabric mod";
      artifactVersion = jsonDecode(utf8.decode(fmjFile.content))["version"];
    } else if (mod.modloader == "forge") {
      var modTomlFile = archive.findFile("META-INF/mods.toml");
      if (modTomlFile == null) throw "The provided artifact is not a forge mod";
      artifactVersion = TomlDocument.parse(utf8.decode(modTomlFile.content)).toMap()["mods"][0]["version"];
    }

    var parsedGameVersions = <Version>[];
    for (var version in gameVersions) {
      try {
        parsedGameVersions.add(Version.parse(version));
      } catch (err) {}
    }

    String minRequiredGameVersion = parsedGameVersions.isNotEmpty
        ? parsedGameVersions.reduce((value, element) => value < element ? value : element).toFancyString()
        : gameVersions[0].toString();

    var determinedVersion = artifactVersion ?? uploadTarget;
    var parsedVersion = Version.parse(determinedVersion);
    var displayVersion = Version(parsedVersion.major, parsedVersion.minor, parsedVersion.patch);

    var versionName = "[$minRequiredGameVersion${parsedGameVersions.length > 1 ? "+" : ""}] ${mod.display_name} - $displayVersion";
    var spec = UploadSpec(targetFile, versionName, determinedVersion, desc, type, gameVersions);

    info("A build with following metadata will be published");
    printKeyValuePair("Name", versionName, 15);
    printKeyValuePair("Version", determinedVersion, 15);
    printKeyValuePair("Release Type", getName(type), 15);
    if (!await ask("Proceed")) return;

    for (var platform in HostAdapter.platforms) {
      if (!mod.platform_ids.keys.contains(platform.toLowerCase())) continue;

      var adapter = HostAdapter(platform.toLowerCase());
      if (args.wasParsed("confirm") && !await ask("Upload to $platform")) continue;

      info("Uploading to $platform");
      if (await adapter.upload(mod, spec)) {
        info("Success");
      }
    }
  }
}
