import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart';

import '../config/config.dart';
import '../config/data.dart';
import '../log.dart';
import '../scatter.dart';
import '../util.dart';
import 'host_adapter.dart';

class ModrinthAdapter extends HostAdapter {
  static const String _url = "https://api.modrinth.com";
  static final ModrinthAdapter instance = ModrinthAdapter._();

  ModrinthAdapter._();

  @override
  Future<List<String>> listVersions() async {
    var response = await client.read(Uri.parse("$_url/api/v1/tag/game_version"));

    var parsed = jsonDecode(response);
    if (parsed is! List<dynamic>) throw "Invalid API response";

    return parsed.cast<String>();
  }

  @override
  Future<bool> isProject(String id) async {
    try {
      var response = await client.get(Uri.parse("$_url/api/v1/mod/$id"));
      debug("Response status: ${response.statusCode}");
      debug("Response body: ${response.body.length > 300 ? "<truncated>" : response.body}");

      return response.statusCode == 200;
    } catch (err) {
      debug(err);
      return false;
    }
  }

  @override
  FutureOr<bool> upload(ModInfo mod, UploadSpec spec) async {
    var json = <String, dynamic>{};
    var filename = basename(spec.file.path);

    json["mod_id"] = mod.platformIds[id];
    json["version_number"] = spec.version;
    json["file_parts"] = [filename];

    json["version_title"] = spec.name;
    json["version_body"] = spec.changelog;
    json["game_versions"] = spec.gameVersions;
    json["release_channel"] = getName(spec.type);
    json["loaders"] = [mod.modloader];
    json["dependencies"] = [];
    json["featured"] = true;

    debug("Request data: ${encoder.convert(json)}");

    var request = MultipartRequest("POST", Uri.parse("$_url/api/v1/version"));

    request
      ..fields["data"] = jsonEncode(json)
      ..files.add(
          await MultipartFile.fromPath(filename, spec.file.path, contentType: MediaType("application", "java-archive")))
      ..headers["Authorization"] = ConfigManager.getToken(id);

    var result = await client.send(request);
    var success = result.statusCode == 200;

    var responseObject = jsonDecode(await utf8.decodeStream(result.stream));

    if (success) {
      info("Modrinth version created: https://modrinth.com/mod/${mod.modId}/version/${responseObject["id"]}");
    } else {
      error(responseObject);
    }

    return success;
  }

  Future<String?> getIdFromSlug(String slug) async {
    final response = await client.get(Uri.parse("$_url/v2/project/$slug"));
    if (response.statusCode == 404) return null;

    final parsed = jsonDecode(response.body);
    if (parsed is! Map<String, dynamic>) throw "Invalid API response";

    debug("Slug query response: $parsed");
    return parsed["id"] as String;
  }

  Future<String?> projectIdFromVersion(String versionId) async {
    final response = await client.get(resolve("version/$versionId"));
    if (response.statusCode != 200) return null;

    final parsed = jsonDecode(response.body);
    if (parsed is! Map<String, dynamic>) throw "Invalid API response";

    return parsed["project_id"];
  }

  Future<dynamic> fetchUnchecked(String route) async {
    return await jsonDecode(await client.read(Uri.parse("$_url/v2/$route")));
  }

  Uri resolve(String route) {
    return Uri.parse("$_url/v2/$route");
  }

  Map<String, String> authHeader() {
    return {"Authorization": ConfigManager.getToken(id)};
  }

  @override
  String get id => "modrinth";
}
