import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:toml/toml.dart';
import 'package:version/version.dart';

import 'color.dart' as c;
import 'config/data.dart';
import 'console.dart';

const JsonEncoder encoder = JsonEncoder.withIndent("    ");

enum Modloader {
  fabric,
  forge,
  quilt,
}

enum DependencyType {
  optional,
  required,
  embedded,
}

enum ReleaseType implements Formattable {
  release(c.green),
  beta(c.yellow),
  alpha(c.red);

  @override
  final c.AnsiControlSequence color;
  const ReleaseType(this.color);
}

class UploadSpec {
  final File file;
  final String name;
  final String version, changelog;
  final ReleaseType type;
  final List<String> gameVersions;
  final List<DependencyInfo> declaredRelations;

  UploadSpec(this.file, this.name, this.version, this.changelog, this.type, this.gameVersions, this.declaredRelations);
}

bool hasValue(List<Enum> values, String valueName) => values.any((element) => element.name == valueName);

String extractVersion(Archive archive, List<Modloader> loaders) {
  String? tryReadVersion(Modloader loader) {
    switch (loader) {
      case Modloader.quilt:
        final qmjFile = archive.findFile("quilt.mod.json");
        return qmjFile != null
            ? jsonDecode(utf8.decode(qmjFile.content as List<int>))["quilt_loader"]["version"] as String
            : null;
      case Modloader.fabric:
        final fmjFile = archive.findFile("fabric.mod.json");
        return fmjFile != null ? jsonDecode(utf8.decode(fmjFile.content as List<int>))["version"] as String : null;
      case Modloader.forge:
        final modTomlFile = archive.findFile("META-INF/mods.toml");
        return modTomlFile != null
            ? TomlDocument.parse(utf8.decode(modTomlFile.content as List<int>)).toMap()["mods"][0]["version"] as String
            : null;
    }
  }

  final version = loaders.map(tryReadVersion).firstWhereOrNull((element) => element != null);
  if (version == null) {
    throw StateError(
        "Could not extract version from metadata for any of the following loaders: ${loaders.map((e) => e.name).join(",")}");
  }

  return version;
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

extension PrintStringList on List<String> {
  void printLines() => print(join("\n"));
}
