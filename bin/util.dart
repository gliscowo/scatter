import 'dart:convert';
import 'dart:io';

import 'package:version/version.dart';

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

  UploadSpec(this.file, this.name, this.version, this.changelog, this.type, this.gameVersions);
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