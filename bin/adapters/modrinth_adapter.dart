import 'dart:convert';

import '../host_adapter.dart';
import '../scatter.dart';

class ModrinthAdapter implements HostAdapter {
  static final ModrinthAdapter instance = ModrinthAdapter._();

  ModrinthAdapter._();

  @override
  Future<List<String>> listVersions() async {
    var response = await client.read(Uri.parse("https://api.modrinth.com/api/v1/tag/game_version"));

    var parsed = jsonDecode(response);
    if (parsed is! List<dynamic>) throw "Invalid API response";

    return parsed.cast<String>();
  }
}
