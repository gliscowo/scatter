import 'package:args/src/arg_results.dart';

import 'scatter_command.dart';

class UploadCommand extends ScatterCommand {
  @override
  final String description = "Upload the given artifact to all available hosts";

  @override
  final String name = "upload";

  @override
  void execute(ArgResults args) async {
    throw UnimplementedError();
  }
}
