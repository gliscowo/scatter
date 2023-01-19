import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';
import 'package:modrinth_api/modrinth_api.dart';
import 'package:path/path.dart';

import '../config/config.dart';
import '../config/data.dart';
import '../scatter.dart';
import '../util.dart';
import 'host_adapter.dart';

class ModrinthAdapter extends HostAdapter {
  static const String _url = "https://api.modrinth.com";
  static final ModrinthAdapter instance = ModrinthAdapter._();

  final ModrinthApi api = ModrinthApi.createClient("gliscowo/scatter/$version");

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
      logger.fine("Response status: ${response.statusCode}");
      logger.fine("Response body: ${response.body.length > 300 ? "<truncated>" : response.body}");

      return response.statusCode == 200;
    } catch (err) {
      logger.fine(err);
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
    json["loaders"] = [for (var loader in mod.loaders) loader.name];
    json["dependencies"] = [
      for (var relation in mod.relations)
        if (relation.projectIds.containsKey(id) && relation.projectIds[id] != null)
          {
            "dependency_type": relation.type == "optional" ? "optional" : "required",
            "project_id": relation.projectIds[id]
          }
    ];

    logger.fine("Request data: ${encoder.convert(json)}");

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
      logger.info("Modrinth version created: https://modrinth.com/mod/${mod.modId}/version/${responseObject["id"]}");
    } else {
      logger.severe("Could not create version: ", responseObject);
    }

    return success;
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
