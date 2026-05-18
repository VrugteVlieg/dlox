import 'dart:io';
import 'package:dlox/scanner/token.dart';
import 'package:dlox/dlox.dart' as dlox;
import 'package:dlox/runner.dart';
import 'package:logging/logging.dart';

final DefaultRunner runtime = DefaultRunner();

Logger _l = Logger("dlox");

Future<void> main(List<String> cliArgs) async {
  List<String> args = cliArgs.toList();
  initLoggers();
  dlox.setRuntime(runtime);
  if (args.length > 2) {
    print("Too many arguments");
    printUsage();
    exit(64);
  } else if (args.length == 2) {
    try {
      CommandArgsPair toRun = Commands.parseFromCli(args);
      await toRun.$1.execute(toRun.$2);
    } on String catch (e) {
      print("Error parsing cli commands: $e");
      printUsage();
    }
  } else {
    await dlox.runPrompt();
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

class DefaultRunner implements DloxRunner {
  bool parserErrorEncountered = false;

  @override
  void exitWCode(int code) {
    exit(code);
  }

  @override
  void writeStdOut(Object? toWrite) {
    print(toWrite);
  }

  @override
  void reportParserError(Token token, String message) {
    parserErrorEncountered = true;
    if (token.type == .EOF) {
      _l.shout("${token.line} at the end $message");
    } else {
      _l.shout("${token.line} at ${token.lexeme} $message");
    }
  }

  @override
  Future<String> readStdIn() async {
    String value = stdin.readLineSync() ?? "";
    _l.info("Read $value");
    return Future.syncValue(value);
  }
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

  Future<Object?> execute(Object? args) {
    switch (this) {
      case Commands.Run:
        String fileToRun = args as String;
        dlox.runFile(fileToRun);
      case Commands.Format:
        String codeToFormat = args as String;
        String toPrint = dlox.format(codeToFormat);
        print(
          runtime.parserErrorEncountered
              ? "Error while formatting code:\n$codeToFormat"
              : toPrint,
        );
    }
    return Future.value(null);
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
