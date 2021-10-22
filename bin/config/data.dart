// ignore_for_file: non_constant_identifier_names

import 'package:json_annotation/json_annotation.dart';

import '../log.dart';

part 'data.g.dart';

enum Modloader { fabric, forge }

enum DependencyType { optional, required, embedded }

@JsonSerializable()
class Tokens {
  final Map<String, String> tokens;

  Tokens(this.tokens);

  factory Tokens.fromJson(Map<String, dynamic> json) => _$TokensFromJson(json);

  Map<String, dynamic> toJson() => _$TokensToJson(this);
}

@JsonSerializable()
class Config {
  Config();

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

@JsonSerializable()
class ModInfo {
  String display_name, mod_id;

  String modloader;

  String? artifact_directory, artifact_filename_pattern;

  final Map<String, String> platform_ids;

  final List<DependencyInfo> relations;

  ModInfo(this.display_name, this.mod_id, this.modloader, this.platform_ids, this.relations, this.artifact_directory, this.artifact_filename_pattern);

  factory ModInfo.fromJson(Map<String, dynamic> json) => _$ModInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ModInfoToJson(this);

  bool artifactLocationDefined() => artifact_filename_pattern != null && artifact_directory != null;

  void dumpToConsole() {
    printKeyValuePair("Name", "$display_name ($mod_id)");
    printKeyValuePair("Modloader", modloader);
    platform_ids.forEach((key, value) {
      printKeyValuePair("$key project id", value);
    });

    printKeyValuePair("Artifact directory", artifact_directory ?? "<undefined>");
    printKeyValuePair("Artifact filename pattern", artifact_filename_pattern ?? "<undefined>");

    if (relations.isEmpty) {
      print("No dependencies defined");
    } else {
      print("Dependencies:");
      for (var info in relations) {
        printKeyValuePair("  Slug", info.slug);
        printKeyValuePair("  Type", info.type);
        print("");
      }
    }
  }
}

@JsonSerializable()
class DependencyInfo {
  String slug, type;

  DependencyInfo(this.slug, this.type);

  factory DependencyInfo.fromJson(Map<String, dynamic> json) => _$DependencyInfoFromJson(json);

  Map<String, dynamic> toJson() => _$DependencyInfoToJson(this);
}
