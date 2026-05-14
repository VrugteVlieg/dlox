import 'dart:io';
import 'cli.dart';

import 'package:dlox/dlox.dart' as dlox;
import 'package:dlox/runner.dart';
import 'package:logging/logging.dart';

void main(List<String> cliArgs) {
  List<String> args = cliArgs.toList();
  initLoggers();
  dlox.setRuntime(DefaultRunner());
  if (args.length > 2) {
    print("Too many arguments");
    printUsage();
    exit(64);
  } else if (args.length == 2) {
    try {
    CommandArgsPair toRun = Commands.parseFromCli(args);
    toRun.$1.execute(toRun.$2);
    } on String catch (e) {
      print("Error parsing cli commands: $e");
      printUsage();
    }
  } else {
    dlox.runPrompt();
  }
}

void initLoggers() {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen(
    (record) => print(
      "${record.loggerName.split(".").last}[${record.level}]@${record.time}: ${record.message}",
    ),
  );
}

