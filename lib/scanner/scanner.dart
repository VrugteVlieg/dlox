import 'package:dlox/dlox.dart';
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
    _tokens.add(Token(.EOF, "", null, _line));
    return _tokens;
  }

  bool isAtTheEnd() => _current >= _sauce.length;

  void _scanToken() {
    String c = advance();
    switch (c) {
      case '(':
        addToken(.LEFT_PAREN);
        break;
      case ')':
        addToken(.RIGHT_PAREN);
        break;
      case '{':
        addToken(.LEFT_BRACE);
        break;
      case '}':
        addToken(.RIGHT_BRACE);
        break;
      case ',':
        addToken(.COMMA);
        break;
      case '.':
        addToken(.DOT);
        break;
      case '-':
        addToken(.MINUS);
        break;
      case '+':
        addToken(.PLUS);
        break;
      case ';':
        addToken(.SEMICOLON);
        break;
      case '*':
        addToken(.STAR);
        break;
      case '!':
        addToken(match("=") ? .BANG_EQUAL : .BANG);
        break;
      case '=':
        addToken(match("=") ? .EQUAL_EQUAL : .EQUAL);
        break;
      case '<':
        addToken(match("=") ? .LESS_EQUAL : .LESS);
        break;
      case '>':
        addToken(match("=") ? .GREATER_EQUAL : .GREATER);
        break;
      case '?':
        addToken(.QUESTION);
        break;
      case ':':
        addToken(.COLON);
      case "/":
        if (match("/")) {
          while (peek() != "\n" && !isAtTheEnd()) {
            advance();
          }
        } else {
          addToken(.SLASH);
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
          hadError = true;
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
    addToken(.NUMBER,
        literal: double.parse(_sauce.substring(_start, _current)));
  }

  void identifier() {
    while (isAlphaNumeric(peek())) {
      advance();
    }

    String text = _sauce.substring(_start, _current);
    addToken(keywordMappings[text] ?? .IDENTIFIER);
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
      hadError = true;
      return;
    }

    advance();
    String value = _sauce.substring(_start + 1, _current - 1);
    addToken(.STRING, literal: value);
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
