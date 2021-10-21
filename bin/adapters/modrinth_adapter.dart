import 'dart:async';
import 'dart:convert';

import '../scatter.dart';
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
      await client.read(Uri.parse("$_url/api/v1/mod/$id"));
      return true;
    } catch (err) {
      return false;
    }
  }

  @override
  String getId() => "modrinth";
}
