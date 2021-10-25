import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:args/src/arg_results.dart';
import 'package:toml/toml.dart';

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
  }

  @override
  void execute(ArgResults args) async {
    if (args.rest.length < 2) throw "Missing arguments. Usage: 'scatter upload <mod> <version or file>'";

    var mod = ConfigManager.getMod(args.rest[0]);
    if (mod == null) throw "Unknown mod id: '${args.rest[0]}'";

    File targetFile;
    var uploadTarget = args.rest[1];
    if (mod.artifactLocationDefined() && !args.wasParsed("read-as-file")) {
      var targetFileLocation = "${mod.artifact_directory!}/${mod.artifact_filename_pattern!.replaceAll("{}", uploadTarget)}";
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

    var spec = UploadSpec(targetFile, artifactVersion ?? uploadTarget, desc, type, gameVersions);

    HostAdapter("modrinth").upload(mod, spec);

    throw UnimplementedError();
  }
}
