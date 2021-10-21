import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:console/console.dart';
import 'package:http/http.dart';

import '../log.dart';
import '../scatter.dart';
import 'host_adapter.dart';

class CurseForgeAdapter implements HostAdapter {
  static const String _url = "https://minecraft.curseforge.com";
  static final CurseForgeAdapter instance = CurseForgeAdapter._();

  String? _token;

  CurseForgeAdapter._();

  @override
  Future<List<String>> listVersions() async {
    ensureTokenLoaded();

    var response = await client.read(Uri.parse("$_url/api/game/versions"), headers: {"X-Api-Token": _token!});

    var parsed = jsonDecode(response);
    if (parsed is! List<dynamic>) throw "Invalid API response";

    List<String> results = [];

    for (Map<String, dynamic> version in parsed) {
      if (version["gameVersionTypeID"] == 3 || version["gameVersionTypeID"] == 73247) continue;
      results.add("${Color.WHITE}Name: ${Color.DARK_BLUE}${version["name"]} ${Color.GRAY}| ${Color.WHITE}Slug: ${Color.DARK_BLUE}${version["slug"]}");
    }

    return results;
  }

  void ensureTokenLoaded() {
    if (_token != null) return;
    var file = File("curseforge_token");

    if (!file.existsSync()) throw "No CurseForge token found";

    _token = (file.readAsStringSync()).replaceAll("\n", "");
  }

  @override
  FutureOr<bool> isProject(String id) async {
    ensureTokenLoaded();
    try {
      var response = await client.get(Uri.parse("$_url/api/projects/$id/localization/export"), headers: {"X-Api-Token": _token!});

      debug("Response status: ${response.statusCode}");
      debug("Response body: ${response.body.length > 300 ? "<truncated>" : response.body}");

      return response.statusCode == 403;
    } on ClientException catch (err) {
      debug(err);
      return false;
    }
  }
}
