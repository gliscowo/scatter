import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';

import '../color.dart' as c;
import '../config/config.dart';
import '../config/data.dart';
import '../console.dart';
import '../scatter.dart';
import '../util.dart';
import 'host_adapter.dart';

final class CurseForgeAdapter extends HostAdapter {
  static const String _url = "https://minecraft.curseforge.com";
  static final RegExp _snapshotRegex = RegExp("([0-9]{2}w[0-9]{2}[a-z])|(.+-(pre|rc)[0-9])");
  static final CurseForgeAdapter instance = CurseForgeAdapter._();

  static const _blacklistedVersions = [9970, 9974];

  CurseForgeAdapter._();

  @override
  Future<List<String>> listVersions() async {
    var response = await client.read(Uri.parse("$_url/api/game/versions"), headers: createTokenHeader());

    var parsed = jsonDecode(response);
    if (parsed is! List<dynamic>) throw "Invalid API response";

    List<String> results = [];

    for (Map<String, dynamic> version in parsed.cast()) {
      if (version["gameVersionTypeID"] == 3 || version["gameVersionTypeID"] == 73247) continue;
      results.add(
          "${c.white}Name: ${c.blue}${version["name"]} ${c.brightBlack}| ${c.white}ID: ${c.blue}${version["id"]} ${c.brightBlack}| ${c.white}Slug: ${c.blue}${version["slug"]} ${c.brightBlack}| ${c.white}Type ID: ${c.blue}${version["gameVersionTypeID"]}");
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

    var mappedGameVersions = <String>[];

    for (var version in spec.gameVersions) {
      if (!_snapshotRegex.hasMatch(version)) {
        mappedGameVersions.add(version);
        continue;
      }

      mappedGameVersions.add(prompt("Enter CurseForge equivalent of snapshot version $version"));
    }

    mappedGameVersions
        .addAll(mod.loaders.map((e) => e.name).map((loader) => loader[0].toUpperCase() + loader.substring(1)));
    var versions = <int>{};
    for (var version in mappedGameVersions) {
      try {
        versions.add(parsed.firstWhere(
                (element) => element["name"] == version && !_blacklistedVersions.contains(element["id"] as int))["id"]
            as int);
      } catch (err) {
        throw "Could not locate CurseForge mapping for version '$version'";
      }
    }

    json["changelog"] = spec.changelog;
    json["changelogType"] = "markdown";
    json["displayName"] = spec.name;
    json["gameVersions"] = versions.toList();
    json["releaseType"] = spec.type.name;

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

  @override
  FutureOr<HttpResult<(), String>> validateToken() {
    return client
        .get(Uri.parse("$_url/api/game/versions"), headers: createTokenHeader())
        .then((value) => value.statusCode == 200 ? Ok(()) : Error(jsonDecode(value.body)["errorMessage"] as String));
  }
}
