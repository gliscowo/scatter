import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:version/version.dart';

import '../config/data.dart';
import '../log.dart';
import '../scatter.dart';
import '../util.dart';
import 'host_adapter.dart';

class ModrinthAdapter implements HostAdapter {
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
  FutureOr<bool> upload(ModInfo mod, UploadSpec spec) {
    var json = <String, dynamic>{};

    json["mod_id"] = mod.mod_id;
    json["version_number"] = spec.version;

    var gameVersion = spec.gameVersions.map(Version.parse);
    var minGameVersion = gameVersion.reduce((value, element) => value < element ? value : element);

    json["versions_title"] = "[${minGameVersion.toFancyString()}${gameVersion.length > 1 ? "+" : ""}] ${mod.display_name} - ${spec.version}";

    json["version_body"] = spec.description;
    json["game_versions"] = spec.gameVersions;
    json["release_channel"] = getName(spec.type);
    json["loaders"] = [mod.modloader];

    print(JsonEncoder.withIndent("    ").convert(json));

    return false;
  }

  @override
  String getId() => "modrinth";
}
