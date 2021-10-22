import 'dart:convert';
import 'dart:io';

import '../log.dart';
import 'data.dart';

typedef Deserializer<T> = T Function(Map<String, dynamic> json);

class ConfigManager {
  static const JsonEncoder _encoder = JsonEncoder.withIndent("    ");

  static final Map<ConfigType, ConfigStore> _configs = {
    ConfigType.config: ConfigStore<Config>(Config(), (json) => Config.fromJson(json), ConfigType.config),
    ConfigType.database: ConfigStore<Database>(Database({}), (json) => Database.fromJson(json), ConfigType.database),
    ConfigType.tokens: ConfigStore<Tokens>(Tokens({}), (json) => Tokens.fromJson(json), ConfigType.tokens)
  };

  static void loadConfigs() {
    Directory(_getConfigDirectory()).createSync(recursive: true);

    _configs.forEach((type, config) {
      config.read(_encoder);
    });
  }

  // Mod info managements

  static ModInfo? getMod(String modId) {
    return getConfigObject(ConfigType.database).mods[modId];
  }

  static void addMod(ModInfo info) {
    var added = getConfigObject(ConfigType.database).mods[info.mod_id] = info;
    _save(ConfigType.database);
  }

  static bool removeMod(String modid) {
    var removed = getConfigObject(ConfigType.database).mods.remove(modid);
    _save(ConfigType.database);
    return removed != null;
  }

  // Token management

  static void setToken(String platform, String? token) {
    if (token == null) {
      getConfigObject(ConfigType.tokens).tokens.remove(platform);
    } else {
      getConfigObject(ConfigType.tokens).tokens[platform] = token;
    }
    _save(ConfigType.tokens);
  }

  static String getToken(String platform) {
    var tokens = getConfigObject(ConfigType.tokens).tokens;
    if (!tokens.containsKey(platform)) throw "No token saved for platform '$platform'. Use 'scatter config --set-token $platform'";
    return tokens[platform]!;
  }

  // Utility

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

  static void _save(ConfigType config) {
    _configs[config]!.save(_encoder);
  }

  static T getConfigObject<T>(ConfigType<T> type) {
    return (_configs[type] as ConfigStore<T>).data;
  }
}

class ConfigStore<T> {
  final Deserializer deserializer;
  final ConfigType<T> type;
  late final File file;

  T data;

  ConfigStore(this.data, this.deserializer, this.type) {
    file = File("${ConfigManager._getConfigDirectory()}${type.name}.json");
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
    debug("Saving $file");

    file.writeAsStringSync(encoder.convert(data));
  }
}

class ConfigType<T> {
  static final ConfigType<Database> database = ConfigType("database");
  static final ConfigType<Tokens> tokens = ConfigType("tokens");
  static final ConfigType<Config> config = ConfigType("config");

  static final Map<String, ConfigType> _byName = {"database": database, "tokens": tokens, "config": config};

  final String name;

  ConfigType(this.name);

  static ConfigType? get(String name) {
    return _byName[name];
  }
}
