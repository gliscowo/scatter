import 'dart:convert';
import 'dart:io';

import '../log.dart';
import 'data.dart';

class DatabaseManager {
  static final JsonEncoder encoder = JsonEncoder.withIndent("    ");
  static Database _database = Database({});

  static void loadDatabase() {
    var databaseFile = File("${Platform.environment["HOME"]}/.config/scatter_config.json");

    if (!databaseFile.existsSync()) {
      info("No config file found, creating from defaults");
      databaseFile.createSync();
      databaseFile.writeAsStringSync(encoder.convert(_database));
    } else {
      _database = Database.fromJson(jsonDecode(databaseFile.readAsStringSync()));
    }
  }

  static ModInfo? getMod(String modId) {
    return _database.mods[modId];
  }
}
