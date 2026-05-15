import "dart:io";

import "package:dlox/parser/mod.dart";
import "package:dlox/parser/tree_walkers/eval/eval.dart";
import "package:dlox/parser/tree_walkers/resolver/resolver.dart";
import "package:dlox/runner.dart";
import "package:dlox/scanner/scanner.dart";
import "package:dlox/scanner/token.dart";
import "package:logging/logging.dart";


//TODO Make this an instance based class instead of this weird singleton situation
bool hadError = false;
bool hadRuntimeError = false;
Logger logger = Logger("DloxInterpreter");
late DloxRunner runtime;
const int ScannerErrorExit = 65;
const int FileNotFoundExit = 70;

void runFile(String path) {
  run(File(path).readAsStringSync());
  if (hadRuntimeError) {
    runtime.exitWCode(FileNotFoundExit);
  }
}

void setRuntime(DloxRunner rt) => runtime = rt;

String format(String code) {
  var (_, program) = parse(code);
  logger.info("Parsed program: $program");
  return program.map((e) => e.prettyPrint).join("\n");
}

(List<Token> tokens, List<LoxNode>) parse(String code) {
  List<Token> tokens = Scanner(code).scanTokens();
  return (tokens, Parser(tokens).parse());
}

void run(String code) {
  logger.fine("Running $code");
  var (tokens, program) = parse(code);
  if (hadError) runtime.exitWCode(ScannerErrorExit); //TODO We should encode the error in the return type of parse instead of using a flag that gets set, the parse can maintain an internal flag but that should not leak out like this
  if (program.isEmpty) return;
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
