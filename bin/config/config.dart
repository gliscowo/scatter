import 'dart:convert';
import 'dart:io';

import '../log.dart';
import 'data.dart';

typedef Deserializer<T> = T Function(Map<String, dynamic> json);

class ConfigManager {
  static const JsonEncoder _encoder = JsonEncoder.withIndent("    ");

  static final Map<ConfigType, ConfigStore> _configs = {
    ConfigType.config: ConfigStore(Config(), (json) => Config.fromJson(json), ConfigType.config),
    ConfigType.database: ConfigStore(Database({}), (json) => Database.fromJson(json), ConfigType.database),
    ConfigType.tokens: ConfigStore(Tokens({}), (json) => Tokens.fromJson(json), ConfigType.tokens)
  };

  static void loadConfigs() {
    Directory(_getConfigDirectory()).createSync(recursive: true);

    _configs.forEach((type, config) {
      config.read(_encoder);
    });
  }

  static ModInfo? getMod(String modId) {
    return (_configs[ConfigType.database] as Database).mods[modId];
  }

  static String dumpConfig(ConfigType type) {
    return _encoder.convert(_configs[type]!.data);
  }

  static String getConfigFile(ConfigType type) {
    return _configs[type]!.file.toString();
  }

  static String _getConfigDirectory() {
    if (Platform.isWindows) return "${Platform.environment["APPDATA"]}\\scatter\\";
    return "${Platform.environment["HOME"]}/.config/scatter/";
  }
}

class ConfigStore<T> {
  final ConfigType type;
  final String name;

  late final File file;
  T data;

  final Deserializer deserializer;

  ConfigStore(this.data, this.deserializer, this.type) : name = type.toString().split('.')[1] {
    file = File("${ConfigManager._getConfigDirectory()}$name.json");
  }

  void read(JsonEncoder encoder) {
    debug("Reading $file");

    if (!file.existsSync()) {
      file.createSync();
      file.writeAsStringSync(encoder.convert(data));
    } else {
      data = deserializer(jsonDecode(file.readAsStringSync()));
    }
  }

  void save(JsonEncoder encoder) {
    file.writeAsStringSync(encoder.convert(data));
  }
}

enum ConfigType { config, database, tokens }
