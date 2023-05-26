import 'dart:convert';
import 'dart:io';

import '../commands/upload_command.dart';
import '../scatter.dart';
import '../util.dart';
import 'data.dart';

typedef Deserializer<T> = T Function(Map<String, dynamic> json);

class ConfigManager {
  ConfigManager._();

  static final Map<Type, ConfigStore<dynamic>> _configs = {
    Config: ConfigStore<Config>(Config([], ChangelogMode.editor), Config.fromJson, "config"),
    Database: ConfigStore<Database>(Database({}), Database.fromJson, "database"),
    Tokens: ConfigStore<Tokens>(Tokens({}), Tokens.fromJson, "tokens"),
  };

  static const Map<String, Type> typesByName = {
    "config": Config,
    "database": Database,
    "tokens": Tokens,
  };

  static void loadConfigs() {
    Directory(_getConfigDirectory()).createSync(recursive: true);

    _configs.forEach((type, config) {
      config.load(encoder);
    });
  }

  // Config management

  static bool removeDefaultVersion(String version) {
    var removed = getDefaultVersions().remove(version);
    save<Config>();
    return removed;
  }

  static bool addDefaultVersion(String version) {
    if (getDefaultVersions().contains(version)) return false;
    getDefaultVersions().add(version);
    save<Config>();
    return true;
  }

  static List<String> getDefaultVersions() {
    return get<Config>().defaultTargetVersions;
  }

  // Mod info management

  static ModInfo? getMod(String modId) {
    return get<Database>().mods[modId];
  }

  static ModInfo requireMod(String modId) {
    final mod = getMod(modId);
    if (mod == null) throw "No mod with id '$modId' found in database";
    return mod;
  }

  static void storeMod(ModInfo info) {
    get<Database>().mods[info.modId] = info;
    save<Database>();
  }

  static bool removeMod(String modid) {
    var removed = get<Database>().mods.remove(modid);
    save<Database>();
    return removed != null;
  }

  // Token management

  static void setToken(String platform, String? token) {
    if (token == null) {
      get<Tokens>().tokens.remove(platform);
    } else {
      get<Tokens>().tokens[platform] = token;
    }
    save<Tokens>();
  }

  static String getToken(String platform) {
    var tokens = get<Tokens>().tokens;
    if (!tokens.containsKey(platform)) {
      throw "No token saved for platform '$platform'. Use 'scatter config --set-token $platform'";
    }
    return tokens[platform]!;
  }

  // Import / Export

  static String export() {
    var exportData = <String, dynamic>{};
    exportData["config"] = get<Config>();
    exportData["database"] = get<Database>();

    return encoder.convert(exportData);
  }

  static void import(String json) {
    var exportData = jsonDecode(json);
    _configs[Config]!.deserialize(exportData["config"] as Map<String, dynamic>);
    _configs[Database]!.deserialize(exportData["database"] as Map<String, dynamic>);
    save<Config>();
    save<Database>();
  }

  // Utility

  static String dumpObject(Type objectType) {
    return encoder.convert(_configs[objectType]!.data);
  }

  static String getFilePath(Type objectType) {
    return _configs[objectType]!.file.path;
  }

  static String _getConfigDirectory() {
    if (Platform.isWindows) return "${Platform.environment["APPDATA"]}\\scatter\\";
    return "${Platform.environment["HOME"]}/.config/scatter/";
  }

  static void save<T>() {
    _configs[T]!.save(encoder);
  }

  static T get<T>() {
    return (_configs[T] as ConfigStore<T>).data;
  }
}

class ConfigStore<T> {
  final Deserializer<T> deserializer;
  final File file;

  T data;

  ConfigStore(this.data, this.deserializer, String name)
      : file = File("${ConfigManager._getConfigDirectory()}$name.json");

  void load(JsonEncoder encoder) {
    logger.fine("Reading $file");

    if (!file.existsSync()) {
      file.createSync();
      file.writeAsStringSync(encoder.convert(data));
    } else {
      deserialize(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
    }
  }

  void deserialize(Map<String, dynamic> json) {
    data = deserializer(json);
  }

  void save(JsonEncoder encoder) {
    logger.fine("Saving $file");

    file.writeAsStringSync(encoder.convert(data));
  }
}
