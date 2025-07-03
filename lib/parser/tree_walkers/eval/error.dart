part of "eval.dart";

class RuntimeError extends UnsupportedError {
  final Token token;

  RuntimeError(this.token, String message) : super(message);
}
