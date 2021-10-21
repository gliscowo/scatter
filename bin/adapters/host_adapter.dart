import 'dart:async';

import 'curseforge_adapter.dart';
import 'modrinth_adapter.dart';

abstract class HostAdapter {
  static const List<String> platforms = ["Modrinth", "CurseForge"];

  factory HostAdapter(String platform) {
    if (platform == "modrinth") return ModrinthAdapter.instance;
    if (platform == "curseforge") return CurseForgeAdapter.instance;
    throw "Unknown host platform";
  }

  String getId();

  FutureOr<List<String>> listVersions();

  FutureOr<bool> isProject(String id);
}
