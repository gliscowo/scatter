import 'package:args/src/arg_results.dart';

import '../config/config.dart';
import '../console.dart';
import '../scatter.dart';
import 'scatter_command.dart';

class RemoveCommand extends ScatterCommand {
  RemoveCommand() : super("remove", "Removes the specified mod from the database", requiredArgCount: 1);

  @override
  void execute(ArgResults args) async {
    var modId = args.rest[0];
    var mod = ConfigManager.getMod(modId);

    if (mod == null) throw "No mod with id '$modId' found in database";

    if (!ask("Remove mod '${mod.displayName}' from the database")) return;

    if (!ConfigManager.removeMod(modId)) throw "Could not remove '$modId' from the database";
    logger.info("'${mod.displayName}' successfully removed");
  }
}
