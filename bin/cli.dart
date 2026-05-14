import 'dart:io';

import 'package:dlox/dlox.dart' as dlox;

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
