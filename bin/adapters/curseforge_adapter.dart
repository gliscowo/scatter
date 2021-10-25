import 'dart:async';
import 'dart:convert';

import 'package:console/console.dart';

import '../config/config.dart';
import '../config/data.dart';
import '../log.dart';
import '../scatter.dart';
import '../util.dart';
import 'host_adapter.dart';

class CurseForgeAdapter implements HostAdapter {
  static const String _url = "https://minecraft.curseforge.com";
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
      results.add("${Color.WHITE}Name: ${Color.DARK_BLUE}${version["name"]} ${Color.GRAY}| ${Color.WHITE}Slug: ${Color.DARK_BLUE}${version["slug"]}");
    }

    return results;
  }

  @override
  FutureOr<bool> isProject(String id) async {
    try {
      var response = await client.get(Uri.parse("$_url/api/projects/$id/localization/export"), headers: createTokenHeader());

      debug("Response status: ${response.statusCode}");
      debug("Response body: ${response.body.length > 300 ? "<truncated>" : response.body}");

      return response.statusCode == 403;
    } catch (err) {
      debug(err);
      return false;
    }
  }

  @override
  FutureOr<bool> upload(ModInfo mod, UploadSpec spec) {

    return true;
  }

  @override
  String getId() => "curseforge";

  Map<String, String> createTokenHeader() {
    return {"X-Api-Token": ConfigManager.getToken(getId())};
  }
}
