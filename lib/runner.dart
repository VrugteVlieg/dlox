import 'package:dlox/scanner/token.dart';

abstract interface class DloxRunner {
  void exitWCode(int code);
  void writeStdOut(Object? toWrite);
  void reportParserError(Token token, String message);
}
