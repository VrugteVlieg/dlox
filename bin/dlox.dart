import 'dart:io';

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

void printUsage() {
  print(
    "Usage dlox (${Commands.values.map((e) => e.cliVerb()).join("|")}) script",
  );
}

typedef CommandArgsPair = (Commands, Object);

enum Commands {
  Run,
  Format;

  String cliVerb() => switch (this) {
    Commands.Run => "run",
    Commands.Format => "format",
  };

  Object parseArguments(List<String> args) {
    switch (this) {
      case Commands.Run:
        return args.removeAt(0);
      case Commands.Format:
        String filePath = args.removeAt(0);
        return File(filePath).readAsStringSync();
    }
  }

  Object? execute(Object? args) {
    switch (this) {
      case Commands.Run:
        String fileToRun = args as String;
        dlox.runFile(fileToRun);
      case Commands.Format:
        String codeToFormat = args as String;
        print(dlox.format(codeToFormat)?? "Error while formatting code:\n$codeToFormat");
    }
    return null;
  }

  static CommandArgsPair parseFromCli(List<String> args) {
    String verb = args.removeAt(0);
    try {
      Commands toParse = Commands.values.firstWhere((e) => e.cliVerb() == verb);
      Object commandArgs = toParse.parseArguments(args);
      return (toParse, commandArgs);
    } on StateError {
      throw "Unknown command $verb";
    }
  }
}
