import "dart:io";

import "package:dlox/parser/mod.dart";
import "package:dlox/parser/tree_walkers/eval/eval.dart";
import "package:dlox/parser/tree_walkers/pretty_print/pretty_print.dart";
import "package:dlox/parser/tree_walkers/resolver/resolver.dart";
import "package:dlox/scanner/scanner.dart";
import "package:dlox/scanner/token.dart";
import "package:logging/logging.dart";

bool hadError = false;
bool hadRuntimeError = false;
Logger logger = Logger("lib.dlox");

void runFile(String path) {
  run(File(path).readAsStringSync());

  if (hadError) {
    exit(65);
  }

  if (hadRuntimeError) {
    exit(70);
  }
}

void run(String code) {
  logger.fine("Running $code");
  Scanner scanner = Scanner(code);
  List<Token> tokens = scanner.scanTokens();
  Parser parser = Parser(tokens);
  List<LoxNode>? program = parser.parse();
  if (program == null) return;
  logger.finer("\n\n*******\nProgram parsed successfully\n*******\n\n");
  logger.fine(prettyPrintProgram(program));
  logger.finer("\n\n*******\nResolving variables\n*******\n\n");
  resolve(program);
  if (hadError) return;
  try {
    logger.finer("\n\n*******\nResolved variables: $locals\n*******\n\n");
    execute(program);
  } on RuntimeError catch (e) {
    print("${e.message}\n[line ${e.token.line}]");
    hadRuntimeError = true;
  }
}

void runPrompt() {
  String? line;
  while (true) {
    print("> ");
    line = stdin.readLineSync();
    if (line == null) continue;
    run(line);
    hadError = false;
  }
}

// ignore: constant_identifier_names
