import 'dart:io';

import 'package:dlox/dlox.dart' as dlox;
import 'package:logging/logging.dart';

void main(List<String> args) {
  initLoggers();
  // log("Test", level: Level.INFO.value);
  if (args.length > 1) {
    print("Usage dlox [script]");
    exit(64);
  } else if (args.length == 1) {
    dlox.runFile(args[0]);
  } else {
    dlox.runPrompt();
  }
}

void initLoggers() {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.FINEST;
  Logger.root.onRecord.listen(
      (record) => print("[${record.level}]@${record.time}: ${record.message}"));
}
