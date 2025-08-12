import 'package:dlox/scanner/token.dart';
import 'package:logging/logging.dart';

Logger log = Logger("DloxInterpreter.Scanner");

final RegExp isNumber = RegExp(r'[0-9]');

class Scanner {
  final String _sauce;
  final List<Token> _tokens = [];
  int _start = 0;
  int _current = 0;
  int _line = 1;

  Scanner(this._sauce);

  List<Token> scanTokens() {
    while (!isAtTheEnd()) {
      _start = _current;
      _scanToken();
    }
    _tokens.add(Token(TokenType.EOF, "", null, _line));
    return _tokens;
  }

  bool isAtTheEnd() => _current >= _sauce.length;

  void _scanToken() {
    String c = advance();
    switch (c) {
      case '(':
        addToken(TokenType.LEFT_PAREN);
        break;
      case ')':
        addToken(TokenType.RIGHT_PAREN);
        break;
      case '{':
        addToken(TokenType.LEFT_BRACE);
        break;
      case '}':
        addToken(TokenType.RIGHT_BRACE);
        break;
      case ',':
        addToken(TokenType.COMMA);
        break;
      case '.':
        addToken(TokenType.DOT);
        break;
      case '-':
        addToken(TokenType.MINUS);
        break;
      case '+':
        addToken(TokenType.PLUS);
        break;
      case ';':
        addToken(TokenType.SEMICOLON);
        break;
      case '*':
        addToken(TokenType.STAR);
        break;
      case '!':
        addToken(match("=") ? TokenType.BANG_EQUAL : TokenType.BANG);
        break;
      case '=':
        addToken(match("=") ? TokenType.EQUAL_EQUAL : TokenType.EQUAL);
        break;
      case '<':
        addToken(match("=") ? TokenType.LESS_EQUAL : TokenType.LESS);
        break;
      case '>':
        addToken(match("=") ? TokenType.GREATER_EQUAL : TokenType.GREATER);
        break;
      case '?':
        addToken(TokenType.QUESTION);
        break;
      case ':':
        addToken(TokenType.COLON);
      case "/":
        if (match("/")) {
          while (peek() != "\n" && !isAtTheEnd()) {
            advance();
          }
        } else {
          addToken(TokenType.SLASH);
        }
        break;
      case " " || "\r" || "\t":
        break;
      case "\n":
        _line++;
        break;
      case '"':
        string();
        break;
      default:
        if (isDigit(c)) {
          number();
        } else if (isAlpha(c)) {
          identifier();
        } else {
          log.shout("$_line Unexpected character.");
        }
        break;
    }
  }

  bool isDigit(String? input) {
    if (input == null) return false;
    return isNumber.hasMatch(input);
  }

  bool isAlpha(String? input) {
    if (input == null) return false;

    return input.startsWith(RegExp(r'[A-Za-z_]'));
  }

  bool isAlphaNumeric(String? input) => isAlpha(input) || isDigit(input);

  void number() {
    while (isDigit(peek())) {
      advance();
    }

    if (peek() == "." && isDigit(peekNext())) {
      advance();
    }

    while (isDigit(peek())) {
      advance();
    }

    log.finer("Parsing double from ${_sauce.substring(_start, _current)}");
    addToken(TokenType.NUMBER,
        literal: double.parse(_sauce.substring(_start, _current)));
  }

  void identifier() {
    while (isAlphaNumeric(peek())) {
      advance();
    }

    String text = _sauce.substring(_start, _current);
    addToken(keywordMappings[text] ?? TokenType.IDENTIFIER);
  }

  String? peekNext() {
    if (_current + 1 >= _sauce.length) return null;

    return _sauce.substring(_current + 1);
  }

  void string() {
    while (peek() != '"' && !isAtTheEnd()) {
      if (peek() == "\n") _line++;
      advance();
    }

    if (isAtTheEnd()) {
      log.shout("$_line Unterminated string");
      return;
    }

    advance();
    String value = _sauce.substring(_start + 1, _current - 1);
    addToken(TokenType.STRING, literal: value);
  }

  String? peek() =>
      isAtTheEnd() ? null : _sauce.substring(_current, _current + 1);

  String advance() => _sauce.substring(_current++, _current);

  bool match(String toMatch) {
    if (isAtTheEnd()) return false;

    if (_sauce.substring(_current, _current + 1) != toMatch) return false;

    _current++;
    return true;
  }

  void addToken(TokenType type, {Object? literal}) {
    _tokens
        .add(Token(type, _sauce.substring(_start, _current), literal, _line));
  }
}
