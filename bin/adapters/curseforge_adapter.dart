import 'dart:convert';
import 'dart:io';

import '../host_adapter.dart';
import '../scatter.dart';

class CurseForgeAdapter implements HostAdapter {
  static final CurseForgeAdapter instance = CurseForgeAdapter._();

  String? _token;

  CurseForgeAdapter._();

  @override
  Future<List<String>> listVersions() async {
    await ensureTokenLoaded();

    var response = await client.read(Uri.parse("https://minecraft.curseforge.com/api/game/versions"), headers: {"X-Api-Token": _token!});

    var parsed = jsonDecode(response);
    if (parsed is! List<dynamic>) throw "Invalid API response";

    List<String> results = [];

    for (Map<String, dynamic> version in parsed) {
      if (version["gameVersionTypeID"] == 3 || version["gameVersionTypeID"] == 73247) continue;
      results.add("Name: ${version["name"]} | Slug: ${version["slug"]}");
    }

    return results;
  }

  Future<void> ensureTokenLoaded() async {
    if (_token != null) return;
    var file = File("curseforge_token");

    if (!await file.exists()) throw "No CurseForge token found";

    _token = (await file.readAsString()).replaceAll("\n", "");
  }
}
