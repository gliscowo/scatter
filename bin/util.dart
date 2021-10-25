import 'dart:io';

import 'package:version/version.dart';

enum Modloader { fabric, forge }

enum DependencyType { optional, required, embedded }

enum ReleaseType { alpha, beta, release }

class UploadSpec {
  final File file;

  final String version, description;

  final ReleaseType type;

  final List<String> gameVersions;

  UploadSpec(this.file, this.version, this.description, this.type, this.gameVersions);
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