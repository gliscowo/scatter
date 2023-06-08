import 'package:dart_console/dart_console.dart';
import 'package:json_annotation/json_annotation.dart';

import '../adapters/curseforge_adapter.dart';
import '../adapters/modrinth_adapter.dart';
import '../commands/upload_command.dart';
import '../util.dart';

part 'data.g.dart';

@JsonSerializable()
class Tokens {
  final Map<String, String> tokens;

  Tokens(this.tokens);

  factory Tokens.fromJson(Map<String, dynamic> json) => _$TokensFromJson(json);
  Map<String, dynamic> toJson() => _$TokensToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Config {
  final List<String> defaultTargetVersions;

  @JsonKey(defaultValue: ChangelogMode.editor)
  ChangelogMode defaultChangelogMode;

  Config(this.defaultTargetVersions, this.defaultChangelogMode);

  factory Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ConfigToJson(this);
}

@JsonSerializable()
class Database {
  final Map<String, ModInfo> mods;

  Database(this.mods);

  factory Database.fromJson(Map<String, dynamic> json) => _$DatabaseFromJson(json);
  Map<String, dynamic> toJson() => _$DatabaseToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ModInfo {
  String displayName, modId;
  @JsonKey(fromJson: _parseLoaders, name: "modloader")
  List<Modloader> loaders;
  String? artifactDirectory, artifactFilenamePattern;
  String? changelogLocation;
  String? versionNamePattern;
  final Map<String, String> platformIds;
  final List<DependencyInfo> relations;

  ModInfo(this.displayName, this.modId, this.loaders, this.platformIds, this.relations, this.artifactDirectory,
      this.artifactFilenamePattern, this.changelogLocation);

  factory ModInfo.fromJson(Map<String, dynamic> json) => _$ModInfoFromJson(json);
  Map<String, dynamic> toJson() => _$ModInfoToJson(this);

  bool get hasArtifactLocation => artifactFilenamePattern != null && artifactDirectory != null;

  String format() {
    final modInfo = Table()
      ..title = "$displayName ($modId)"
      ..insertRows([
        [
          "Modloaders",
          [for (var loader in loaders) loader.name]
        ],
        const []
      ])
      ..insertRows([
        for (final entry in platformIds.entries) ["${entry.key} project id", entry.value],
        const []
      ])
      ..insertRow(["Artifact directory", artifactDirectory ?? "<undefined>"])
      ..insertRow(["Artifact filename pattern", artifactFilenamePattern ?? "<undefined>"])
      ..insertRow(["Changelog location", changelogLocation ?? "<undefined>"]);

    final dependencies = Table();

    if (relations.isNotEmpty) {
      dependencies
        ..title = "Dependencies"
        ..insertColumn(header: "Slug")
        ..insertColumn(header: "Type")
        ..insertColumn(header: "Modrinth ID")
        ..insertRows(relations
            .map((info) => [info.slug, info.type, info.projectIds[ModrinthAdapter.instance.id] ?? "<undefined>"])
            .toList());

      final info = modInfo.render();
      final deps = dependencies.render().split("\n");
      final padding = ((info.split("\n").first.length - deps.first.length) ~/ 2) - 1;

      return info + deps.map((e) => " " * padding + e).join("\n");
    } else {
      return modInfo.render();
    }
  }

  static List<Modloader> _parseLoaders(Object json) {
    if (json is String) {
      return [Modloader.values.byName(json)];
    } else if (json is List<dynamic>) {
      return json.cast<String>().map((e) => Modloader.values.byName(e)).toList();
    } else {
      throw ArgumentError.value(json, "modloader", "could not read modloaders from json");
    }
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class DependencyInfo {
  String slug, type;

  @JsonKey(defaultValue: <String, String>{})
  Map<String, String>? platformIds = {};
  Map<String, String> get projectIds => platformIds!;

  DependencyInfo(this.slug, this.type, this.platformIds) {
    if (projectIds.isNotEmpty) return;
    projectIds[CurseForgeAdapter.instance.id] = slug;
  }

  DependencyInfo.simple(this.slug, this.type) {
    projectIds[CurseForgeAdapter.instance.id] = slug;
  }

  factory DependencyInfo.fromJson(Map<String, dynamic> json) => _$DependencyInfoFromJson(json);

  Map<String, dynamic> toJson() => _$DependencyInfoToJson(this);
}
