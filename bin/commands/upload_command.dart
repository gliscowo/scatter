import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:args/src/arg_results.dart';
import 'package:path/path.dart';
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
      if (!mod.artifactLocationDefined())
        throw "No artifact location defined, artifact search is unavailable. Usage: 'scatter upload <mod> <version>'";

      var namePattern = mod.artifact_filename_pattern;
      var fileRegex = RegExp(namePattern!.replaceAll("{}", ".+\\"));

      var artifactDir = Directory(mod.artifact_directory!);
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
          .toList();

      info("The following versions were found:");

      for (int idx = 0; idx < versions.length; idx++) {
        print(
            "[$idx] ${versions[idx]} (${extractVersion(zipDecoder.decodeBytes(files[idx].readAsBytesSync()), modloader)})");
      }

      var uploadIndex = int.parse(await prompt("Number of version to upload"));
      if (uploadIndex > versions.length - 1) throw "Invalid version index";

      uploadTarget = versions[uploadIndex];
    } else {
      uploadTarget = args.rest[1];
    }

    File targetFile;
    if (mod.artifactLocationDefined() && !args.wasParsed("read-as-file")) {
      var targetFileLocation =
          "${mod.artifact_directory!}${mod.artifact_filename_pattern!.replaceAll("{}", uploadTarget)}";
      targetFile = File(targetFileLocation);
    } else {
      targetFile = File(uploadTarget);
    }

    if (!targetFile.existsSync()) throw "Unable to find artifact file: '${targetFile.path}'";

    var desc = await prompt("Changelog");
    var type = getEnum(ReleaseType.values,
        await promptValidated("Release Type", enumMatcher(ReleaseType.values), invalidMessage: "Invalid release type"));

    var gameVersions = ConfigManager.getDefaultVersions();
    if (args.wasParsed("override-game-versions")) {
      var userVersions = (await prompt("Comma-separated game versions")).split(",");
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
      } catch (err) {}
    }

    String minRequiredGameVersion = parsedGameVersions.isNotEmpty
        ? parsedGameVersions.reduce((value, element) => value < element ? value : element).toFancyString()
        : gameVersions[0].toString();

    var parsedVersion = Version.parse(artifactVersion);
    var displayVersion = Version(parsedVersion.major, parsedVersion.minor, parsedVersion.patch);

    var versionName =
        "[$minRequiredGameVersion${parsedGameVersions.length > 1 ? "+" : ""}] ${mod.display_name} - $displayVersion";

    var relations = List.of(mod.relations);

    if (args.wasParsed("confirm-relations")) {
      for (var dep in mod.relations) {
        if (await ask("Declare dependency '${dep.slug}'")) continue;
        relations.remove(dep);
      }
    }

    var spec = UploadSpec(targetFile, versionName, artifactVersion, desc, type, gameVersions, relations);

    info("A build with following metadata will be published");
    printKeyValuePair("Name", versionName, 15);
    printKeyValuePair("Version", artifactVersion, 15);
    printKeyValuePair("Release Type", getName(type), 15);
    if (!await ask("Proceed")) return;

    for (var platform in HostAdapter.platforms) {
      if (!mod.platform_ids.keys.contains(platform.toLowerCase())) continue;

      var adapter = HostAdapter.fromId(platform.toLowerCase());
      if (args.wasParsed("confirm") && !await ask("Upload to $platform")) continue;

      info("Uploading to $platform");
      await adapter.upload(mod, spec);
    }
  }
}
