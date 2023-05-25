import 'dart:async';

import '../config/data.dart';
import '../util.dart';
import 'curseforge_adapter.dart';
import 'github_adapter.dart';
import 'modrinth_adapter.dart';

abstract base class HostAdapter {
  static const List<String> platforms = ["Modrinth", "CurseForge", "GitHub"];

  HostAdapter();

  factory HostAdapter.fromId(String platform) {
    if (platform == "modrinth") return ModrinthAdapter.instance;
    if (platform == "curseforge") return CurseForgeAdapter.instance;
    if (platform == "github") return GitHubAdapter.instance;
    throw "Unknown host platform";
  }

  String idOf(ModInfo mod) {
    var platformId = mod.platformIds[id];
    if (platformId == null) throw "Mod ${mod.displayName} is missing platform id for platform $id";

    return platformId;
  }

  String get id;

  FutureOr<List<String>> listVersions();

  FutureOr<bool> isProject(String id);

  FutureOr<bool> upload(ModInfo mod, UploadSpec spec);

  FutureOr<HttpResult<(), String>> validateToken();
}

sealed class HttpResult<V, E> {}

class Ok<V, E> extends HttpResult<V, E> {
  final V result;
  Ok(this.result);
}

class Error<V, E> extends HttpResult<V, E> {
  final E error;
  Error(this.error);
}
