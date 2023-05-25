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

Config _$ConfigFromJson(Map<String, dynamic> json) => Config(
      (json['default_target_versions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      $enumDecodeNullable(
              _$ChangelogModeEnumMap, json['default_changelog_mode']) ??
          ChangelogMode.editor,
    );

Map<String, dynamic> _$ConfigToJson(Config instance) => <String, dynamic>{
      'default_target_versions': instance.defaultTargetVersions,
      'default_changelog_mode':
          _$ChangelogModeEnumMap[instance.defaultChangelogMode]!,
    };

const _$ChangelogModeEnumMap = {
  ChangelogMode.editor: 'editor',
  ChangelogMode.prompt: 'prompt',
  ChangelogMode.file: 'file',
};

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
      ModInfo._parseLoaders(json['modloader'] as Object),
      Map<String, String>.from(json['platform_ids'] as Map),
      (json['relations'] as List<dynamic>)
          .map((e) => DependencyInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      json['artifact_directory'] as String?,
      json['artifact_filename_pattern'] as String?,
      json['changelog_location'] as String?,
    )..versionNamePattern = json['version_name_pattern'] as String?;

Map<String, dynamic> _$ModInfoToJson(ModInfo instance) => <String, dynamic>{
      'display_name': instance.displayName,
      'mod_id': instance.modId,
      'modloader': instance.loaders.map((e) => _$ModloaderEnumMap[e]!).toList(),
      'artifact_directory': instance.artifactDirectory,
      'artifact_filename_pattern': instance.artifactFilenamePattern,
      'changelog_location': instance.changelogLocation,
      'version_name_pattern': instance.versionNamePattern,
      'platform_ids': instance.platformIds,
      'relations': instance.relations,
    };

const _$ModloaderEnumMap = {
  Modloader.fabric: 'fabric',
  Modloader.forge: 'forge',
  Modloader.quilt: 'quilt',
};

DependencyInfo _$DependencyInfoFromJson(Map<String, dynamic> json) =>
    DependencyInfo(
      json['slug'] as String,
      json['type'] as String,
      (json['platform_ids'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          {},
    );

Map<String, dynamic> _$DependencyInfoToJson(DependencyInfo instance) =>
    <String, dynamic>{
      'slug': instance.slug,
      'type': instance.type,
      'platform_ids': instance.platformIds,
    };
