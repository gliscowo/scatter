import 'adapters/curseforge_adapter.dart';
import 'adapters/modrinth_adapter.dart';

abstract class HostAdapter {
  factory HostAdapter(String platform) {
    if (platform == "modrinth") return ModrinthAdapter.instance;
    if (platform == "curseforge") return CurseForgeAdapter.instance;
    throw "Unknown host platform";
  }

  Future<List<String>> listVersions();
}
