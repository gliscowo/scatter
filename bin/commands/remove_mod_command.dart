import 'package:args/src/arg_results.dart';

import '../config/config.dart';
import '../log.dart';
import 'scatter_command.dart';

class RemoveCommand extends ScatterCommand {
  @override
  final String name = "remove";

  @override
  final String description = "Removes the specified mod from the database";

  @override
  void execute(ArgResults args) async {
    if (args.rest.isEmpty) throw "No mod id provided";

    var modId = args.rest[0];
    var mod = ConfigManager.getMod(modId);

    if (mod == null) throw "No mod with id '$modId' found in database";

    if (!await ask("Remove mod '${mod.display_name}' from the database")) return;

    if (!ConfigManager.removeMod(modId)) throw "Could not remove '$modId' from the database";
    info("'${mod.display_name}' successfully removed");
  }
}
