import 'dart:async';
import 'dart:convert';

import 'package:console/console.dart';
import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';

import '../config/config.dart';
import '../config/data.dart';
import '../console.dart';
import '../scatter.dart';
import '../util.dart';
import 'host_adapter.dart';

class CurseForgeAdapter extends HostAdapter {
  static const String _url = "https://minecraft.curseforge.com";
  static final RegExp _snapshotRegex = RegExp("([0-9]{2}w[0-9]{2}[a-z])|(.+-(pre|rc)[0-9])");
  static final CurseForgeAdapter instance = CurseForgeAdapter._();

  CurseForgeAdapter._();

  @override
  Future<List<String>> listVersions() async {
    var response = await client.read(Uri.parse("$_url/api/game/versions"), headers: createTokenHeader());

    var parsed = jsonDecode(response);
    if (parsed is! List<dynamic>) throw "Invalid API response";

    List<String> results = [];

    for (Map<String, dynamic> version in parsed) {
      if (version["gameVersionTypeID"] == 3 || version["gameVersionTypeID"] == 73247) continue;
      results.add(
          "${Color.WHITE}Name: ${Color.DARK_BLUE}${version["name"]} ${Color.GRAY}| ${Color.WHITE}Slug: ${Color.DARK_BLUE}${version["slug"]}");
    }

    return results;
  }

  @override
  FutureOr<bool> isProject(String id) async {
    try {
      var response =
          await client.get(Uri.parse("$_url/api/projects/$id/localization/export"), headers: createTokenHeader());

      logger.fine("Response status: ${response.statusCode}");
      logger.fine("Response body: ${response.body.length > 300 ? "<truncated>" : response.body}");

      return response.statusCode == 403;
    } catch (err) {
      logger.fine("Caught error whilst checking CurseForge project", err);
      return false;
    }
  }

  @override
  FutureOr<bool> upload(ModInfo mod, UploadSpec spec) async {
    var json = <String, dynamic>{};

    var response = await client.read(Uri.parse("$_url/api/game/versions"), headers: createTokenHeader());
    var parsed = jsonDecode(response);
    if (parsed is! List<dynamic>) throw "Invalid API response";

    var mappedGameVersions = [];

    for (var version in spec.gameVersions) {
      if (!_snapshotRegex.hasMatch(version)) {
        mappedGameVersions.add(version);
        continue;
      }

      mappedGameVersions.add(await prompt("Enter CurseForge equivalent of snapshot version $version"));
    }

    mappedGameVersions.add(mod.modloader.replaceFirst("f", "F"));
    var versions = <int>[];
    for (var version in mappedGameVersions) {
      try {
        versions.add(parsed.firstWhere((element) => element["name"] == version)["id"]);
      } catch (err) {
        throw "Could not locate CurseForge mapping for version '$version'";
      }
    }

    json["changelog"] = spec.changelog;
    json["changelogType"] = "markdown";
    json["displayName"] = spec.name;
    json["gameVersions"] = versions;
    json["releaseType"] = getName(spec.type);

    if (spec.declaredRelations.isNotEmpty) {
      var relationsList = <Map<String, dynamic>>[];

      for (var dependency in spec.declaredRelations) {
        relationsList.add({"slug": dependency.slug, "type": _formatDependency(dependency.type)});
      }

      json["relations"] = {"projects": relationsList};
    }

    logger.fine("Request data: ${encoder.convert(json)}");

    var request = MultipartRequest("POST", Uri.parse("$_url/api/projects/${mod.platformIds[id]}/upload-file"));

    request
      ..fields["metadata"] = jsonEncode(json)
      ..files.add(
          await MultipartFile.fromPath("file", spec.file.path, contentType: MediaType("application", "java-archive")))
      ..headers["X-Api-Token"] = ConfigManager.getToken(id);

    var result = await client.send(request);
    var success = result.statusCode == 200;

    var responseObject = jsonDecode(await utf8.decodeStream(result.stream));

    if (success) {
      logger.info(
          "CurseForge version created: https://www.curseforge.com/minecraft/mc-mods/${mod.modId}/files/${responseObject["id"]}");
    } else {
      logger.severe(responseObject);
    }

    return success;
  }

  String _formatDependency(String type) {
    if (type == "required") return "requiredDependency";
    if (type == "embedded") return "embeddedLibrary";
    if (type == "optional") return "optionalDependency";
    throw "Unreachable";
  }

  @override
  String get id => "curseforge";

  Map<String, String> createTokenHeader() {
    return {"X-Api-Token": ConfigManager.getToken(id)};
  }
}
