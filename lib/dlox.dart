import "dart:io";

import "package:dlox/parser/mod.dart";
import "package:dlox/parser/tree_walkers/eval/eval.dart";
import "package:dlox/parser/tree_walkers/resolver/resolver.dart";
import "package:dlox/runner.dart";
import "package:dlox/scanner/scanner.dart";
import "package:dlox/scanner/token.dart";
import "package:logging/logging.dart";

bool hadError = false;
bool hadRuntimeError = false;
Logger logger = Logger("lib.dlox");
late DloxRunner runtime;

void runFile(String path) {
  run(File(path).readAsStringSync());

  if (hadError) {
    runtime.exitWCode(65);
  }

  if (hadRuntimeError) {
    runtime.exitWCode(70);
  }
}

void setRuntime(DloxRunner rt) => runtime = rt;

String format(String code) {
  var (_, program) = _parse(code);
  return program!.map((e) => e.prettyPrint).join("\n");
}

(List<Token> tokens, List<LoxNode>?) _parse(String code) {
  List<Token> tokens = Scanner(code).scanTokens();
  return (tokens, Parser(tokens).parse());
}

void run(String code) {
  logger.fine("Running $code");
  var (tokens, program) = _parse(code);
  if (program == null) return;
  logger.finer("\n\n*******\nProgram parsed successfully\n*******\n\n");
  logger.fine(program.prettyPrint);
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
