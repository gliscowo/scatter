// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Tokens _$TokensFromJson(Map<String, dynamic> json) => Tokens(
      Map<String, String>.from(json['tokens'] as Map),
    );

Map<String, dynamic> _$TokensToJson(Tokens instance) => <String, dynamic>{
      'tokens': instance.tokens,
    };

Config _$ConfigFromJson(Map<String, dynamic> json) => Config();

Map<String, dynamic> _$ConfigToJson(Config instance) => <String, dynamic>{};

Database _$DatabaseFromJson(Map<String, dynamic> json) => Database(
      (json['mods'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, ModInfo.fromJson(e as Map<String, dynamic>)),
      ),
    );

Map<String, dynamic> _$DatabaseToJson(Database instance) => <String, dynamic>{
      'mods': instance.mods,
    };

ModInfo _$ModInfoFromJson(Map<String, dynamic> json) => ModInfo(
      json['display_name'] as String,
      json['mod_id'] as String,
      json['modloader'] as String,
      Map<String, String>.from(json['platform_ids'] as Map),
      (json['relations'] as List<dynamic>)
          .map((e) => DependencyInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      json['artifact_directory'] as String?,
      json['artifact_filename_pattern'] as String?,
    );

Map<String, dynamic> _$ModInfoToJson(ModInfo instance) => <String, dynamic>{
      'display_name': instance.display_name,
      'mod_id': instance.mod_id,
      'modloader': instance.modloader,
      'platform_ids': instance.platform_ids,
      'relations': instance.relations,
      'artifact_directory': instance.artifact_directory,
      'artifact_filename_pattern': instance.artifact_filename_pattern,
    };

DependencyInfo _$DependencyInfoFromJson(Map<String, dynamic> json) =>
    DependencyInfo(
      json['slug'] as String,
      json['type'] as String,
    );

Map<String, dynamic> _$DependencyInfoToJson(DependencyInfo instance) =>
    <String, dynamic>{
      'slug': instance.slug,
      'type': instance.type,
    };
