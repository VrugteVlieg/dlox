import 'dart:io';

abstract interface class DloxRunner {
  void exitWCode(int code);
  void writeStdOut(Object? toWrite);
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
}
