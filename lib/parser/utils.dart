part of "parser.dart";

void reportError(Token token, String message) {
  if (token.type == TokenType.EOF) {
    logger.shout("${token.line} at the end $message");
  } else {
    logger.shout("${token.line} at ${token.lexeme} $message");
  }
}
