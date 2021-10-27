import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:toml/toml.dart';
import 'package:version/version.dart';

import 'config/data.dart';

const JsonEncoder encoder = JsonEncoder.withIndent("    ");

enum Modloader { fabric, forge }

enum DependencyType { optional, required, embedded }

enum ReleaseType { alpha, beta, release }

class UploadSpec {
  final File file;

  final String name;

  final String version, changelog;

  final ReleaseType type;

  final List<String> gameVersions;

  final List<DependencyInfo> declaredRelations;

  UploadSpec(this.file, this.name, this.version, this.changelog, this.type, this.gameVersions, this.declaredRelations);
}

bool Function(String) enumMatcher(List<Enum> enumValues) {
  return (string) => enumValues.any((element) => getName(element) == string);
}

T getEnum<T extends Enum>(List<T> enumValues, String name) {
  return enumValues.singleWhere((element) => getName(element) == name);
}

String getName<T extends Enum>(T instance) {
  return instance.toString().split('.')[1];
}

String extractVersion(Archive archive, Modloader loader) {
  switch (loader) {
    case Modloader.fabric:
      var fmjFile = archive.findFile("fabric.mod.json");
      if (fmjFile == null) throw "The provided artifact is not a fabric mod";
      return jsonDecode(utf8.decode(fmjFile.content))["version"];
    case Modloader.forge:
      var modTomlFile = archive.findFile("META-INF/mods.toml");
      if (modTomlFile == null) throw "The provided artifact is not a forge mod";
      return TomlDocument.parse(utf8.decode(modTomlFile.content)).toMap()["mods"][0]["version"];
  }
}

extension FancyToString on Version {
  String toFancyString() {
    final StringBuffer output = StringBuffer("$major.$minor${patch != 0 ? ".$patch" : ""}");
    if (preRelease.isNotEmpty) {
      output.write("-${preRelease.join('.')}");
    }
    if (build.trim().isNotEmpty) {
      output.write("+${build.trim()}");
    }
    return output.toString();
  }
}
