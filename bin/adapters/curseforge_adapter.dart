import 'dart:convert';
import 'dart:io';

import 'package:console/console.dart';

import 'host_adapter.dart';
import '../scatter.dart';

class CurseForgeAdapter implements HostAdapter {
  static final CurseForgeAdapter instance = CurseForgeAdapter._();

  String? _token;

  CurseForgeAdapter._();

  @override
  Future<List<String>> listVersions() async {
    ensureTokenLoaded();

    var response = await client.read(Uri.parse("https://minecraft.curseforge.com/api/game/versions"), headers: {"X-Api-Token": _token!});

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
}
