import 'package:json_annotation/json_annotation.dart';

import '../adapters/curseforge_adapter.dart';
import '../adapters/modrinth_adapter.dart';
import '../commands/upload_command.dart';
import '../log.dart';

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

  ChangelogMode? defaultChangelogMode;

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

  String modloader;

  String? artifactDirectory, artifactFilenamePattern;

  final Map<String, String> platformIds;

  final List<DependencyInfo> relations;

  ModInfo(this.displayName, this.modId, this.modloader, this.platformIds, this.relations, this.artifactDirectory,
      this.artifactFilenamePattern);

  factory ModInfo.fromJson(Map<String, dynamic> json) => _$ModInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ModInfoToJson(this);

  bool artifactLocationDefined() => artifactFilenamePattern != null && artifactDirectory != null;

  void dumpToConsole() {
    printKeyValuePair("Name", "$displayName ($modId)");
    printKeyValuePair("Modloader", modloader);
    platformIds.forEach((key, value) {
      printKeyValuePair("$key project id", value);
    });

    printKeyValuePair("Artifact directory", artifactDirectory ?? "<undefined>");
    printKeyValuePair("Artifact filename pattern", artifactFilenamePattern ?? "<undefined>");

    if (relations.isEmpty) {
      print("No dependencies defined");
    } else {
      print("Dependencies:");
      for (var info in relations) {
        printKeyValuePair("  Slug", info.slug);
        printKeyValuePair("  Type", info.type);
        printKeyValuePair("  Modrinth ID", info.project_ids[ModrinthAdapter.instance.id]);
        print("");
      }
    }
  }
}

@JsonSerializable()
class DependencyInfo {
  String slug, type;

  @JsonKey(defaultValue: <String, String>{})
  Map<String, String>? platform_ids = {};
  Map<String, String> get project_ids => platform_ids!;

  DependencyInfo(this.slug, this.type, this.platform_ids) {
    if (project_ids.isNotEmpty) return;
    project_ids[CurseForgeAdapter.instance.id] = slug;
  }

  DependencyInfo.simple(this.slug, this.type) {
    project_ids[CurseForgeAdapter.instance.id] = slug;
  }

  factory DependencyInfo.fromJson(Map<String, dynamic> json) => _$DependencyInfoFromJson(json);

  Map<String, dynamic> toJson() => _$DependencyInfoToJson(this);
}
