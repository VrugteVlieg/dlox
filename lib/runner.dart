import 'dart:io';

import 'package:dlox/parser/mod.dart';
import 'package:dlox/scanner/token.dart';

abstract interface class DloxRunner {
  void exitWCode(int code);
  void writeStdOut(Object? toWrite);
  void reportParserError(Token token, String message);
}

class DefaultRunner implements DloxRunner {
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
    if (token.type == TokenType.EOF) {
      logger.shout("${token.line} at the end $message");
    } else {
      logger.shout("${token.line} at ${token.lexeme} $message");
    }
  }
}
