import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:args/src/arg_results.dart';

import '../config/config.dart';
import '../config/data.dart';
import '../console.dart';
import '../scatter.dart';
import '../util.dart';
import 'scatter_command.dart';

class EditCommand extends ScatterCommand {
  EditCommand() : super("edit", "Edit the specified mod", arguments: ["mod-id"]);

  @override
  void execute(ArgResults args) async {
    var modId = args.rest[0];
    var mod = ConfigManager.requireMod(modId);

    logger.info("Editing mod '${mod.displayName}'");
    logger.info("Type 'done' to exit and save changes, 'save' to save changes");
    logger.info("Type 'quit' to exit without saving changes");

    final runner = CommandRunner<bool>("scatter >", "")
      ..usageFooter
      ..addCommand(PrimitiveCommand.simple("view", "View the current mod configuration", () => print(mod.format())))
      ..addCommand(PrimitiveCommand.simple("save", "Save changes", () => ConfigManager.save<Database>()))
      ..addCommand(PrimitiveCommand("quit", "Quit this interface without saving", () => true))
      ..addCommand(DepmodCommand(mod))
      ..addCommand(SetPropertyCommand(mod))
      ..addCommand(PrimitiveCommand("done", "Save changes and quit this interface", () {
        ConfigManager.save<Database>();
        return true;
      }));

    while (true) {
      console.write("scatter > ");
      var input = console.readLine(cancelOnBreak: true);
      if (input == null) return;

      try {
        final result = await runner.run(input.split(' '));
        if (result != null && result) break;
      } on UsageException catch (_) {
        runner.printUsage();
      }
    }
  }
}

class PrimitiveCommand extends Command<bool> {
  @override
  final String name, description;
  final bool Function() callback;

  PrimitiveCommand(this.name, this.description, this.callback);
  PrimitiveCommand.simple(this.name, this.description, void Function() callback)
      : callback = (() {
          callback();
          return false;
        });

  @override
  FutureOr<bool> run() => callback();
}

class SetPropertyCommand extends Command<bool> {
  static final _props = <String, dynamic Function(ModInfo, String)>{
    "version_name_pattern": (mod, value) => mod.versionNamePattern = value,
    "changelog_location": (mod, value) => mod.changelogLocation = value,
    "artifact_directory": (mod, value) => mod.artifactDirectory = value,
    "artifact_filename_pattern": (mod, value) => mod.artifactFilenamePattern = value,
    "id": (mod, value) {
      if (!ask("This operation will forcibly save all changes and exit edit mode. Continue")) return false;

      ConfigManager.removeMod(mod.modId);

      mod.modId = value;
      ConfigManager.storeMod(mod);

      logger.info("Mod ID changed to '$value'");
      logger.info("Changes saved");
      exit(0);
    },
    "modloaders": (mod, value) {
      final loaders = value.split(",");
      for (final loader in loaders) {
        if (!hasValue(Modloader.values, loader)) {
          logger.warning("Unknown modloader '$loader'. Available: 'fabric', 'forge', 'quilt'");
          return;
        }
      }

      mod.loaders = loaders.map((e) => Modloader.values.byName(e)).toList();
    }
  };

  final ModInfo _mod;
  SetPropertyCommand(this._mod);

  @override
  String get description => "Set a mod property";
  @override
  String get name => "set-prop";
  @override
  String get invocation => super.invocation.replaceFirst(
        "[arguments]",
        "<property> <value>\nValid Properties:\n${_props.keys.map((e) => "   $e").join("\n")}\n",
      );

  @override
  FutureOr<bool> run() {
    if (argResults!.rest case [var prop, var value]) {
      if (!_props.containsKey(prop)) {
        logger.warning("Invalid property");
        return false;
      }

      final result = _props[prop]!(_mod, value);

      if (result is! bool || result) logger.info("property '$prop' updated to '$value'");
    } else {
      logger.severe("Invalid arguments");
      printUsage();
    }
    return false;
  }
}

class DepmodCommand extends Command<bool> {
  @override
  final String name = "depmod", description = "Modify the mod's dependencies";

  DepmodCommand(ModInfo mod) {
    addSubcommand(DepmodAddCommand(mod));
    addSubcommand(DepmodRemoveCommand(mod));
  }
}

class DepmodAddCommand extends Command<bool> {
  final ModInfo _mod;
  DepmodAddCommand(this._mod);

  @override
  final String name = "add", description = "Add a dependency";

  @override
  String get invocation => super.invocation.replaceFirst("[arguments]", "<slug> <type>");

  @override
  FutureOr<bool> run() {
    if (argResults!.rest case [var slug, var type]) {
      if (!hasValue(DependencyType.values, type)) {
        logger.warning("Unknown dependency type");
        return false;
      }

      _mod.relations.add(DependencyInfo.simple(slug, type));
      logger.info("'$slug' added as '$type' dependency");
    } else {
      logger.severe("Invalid arguments");
      printUsage();
    }
    return false;
  }
}

class DepmodRemoveCommand extends Command<bool> {
  final ModInfo _mod;
  DepmodRemoveCommand(this._mod);

  @override
  String get description => "Remove a dependency";
  @override
  String get name => "remove";
  @override
  String get invocation => super.invocation.replaceFirst("[arguments]", "<slug>");

  @override
  FutureOr<bool> run() {
    if (argResults!.rest case [var slug]) {
      if (_mod.relations.any((element) => element.slug == slug)) {
        _mod.relations.removeWhere((element) => element.slug == slug);
        logger.info("Dependency '$slug' removed");
      } else {
        logger.warning("no dependency with slug $slug");
      }
    } else {
      logger.severe("Invalid arguments");
      printUsage();
    }

    return false;
  }
}
