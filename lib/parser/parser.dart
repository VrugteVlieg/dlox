import 'dart:math';

import 'package:dlox/parser/types/types.dart';
import 'package:dlox/scanner/token.dart';
import 'package:logging/logging.dart';

part "utils.dart";

Logger logger = Logger("Parser");

class ParserException implements Exception {}

class Parser {
  final List<Token> tokens;
  int _current = 0;
  int _loopDepth = 0;

  Parser(this.tokens);

  /// Match either a single token type or a list of possible token types
  ///
  /// Advances the token stream if a `matchable` is found
  bool _match(Object matchable) {
    List<TokenType> toMatch =
        matchable is List<TokenType> ? matchable : [matchable as TokenType];
    String surroundingTokens = tokens
        .sublist(max(_current, 0),
            min(tokens.length - 1, _current + (toMatch.length + 2)))
        .map((t) => t.type)
        .join("->");
    logger.finest("Matching $toMatch in [$surroundingTokens]");

    for (TokenType type in toMatch) {
      if (_check(type)) {
        logger.finest("Found $type");
        _advance();
        return true;
      }
    }
    return false;
  }

  List<LoxNode>? parse() {
    try {
      return _parseLox();
    } on ParserException {
      return null;
    }
  }

  Token _advance() {
    if (!_isAtEnd()) _current++;
    return _previous();
  }

  bool _check(TokenType type) => _isAtEnd() ? false : _peek().type == type;

  bool _isAtEnd() => _peek().type == TokenType.EOF;

  Token _peek() => tokens[_current];

  Token _previous() => tokens[_current - 1];

  List<LoxNode> _parseLox() {
    List<LoxNode> statements = [];
    while (!_isAtEnd()) {
      LoxNode? next = _declaration();
      if (next != null) {
        statements.add(next);
      }
    }

    return statements;
  }

  Declaration? _declaration() {
    try {
      if (_match(TokenType.CLASS)) {
        return _classDeclaration();
      }

      if (_match(TokenType.VAR)) {
        return _varDecl();
      }

      if (_match(TokenType.FUN)) {
        if (_check(TokenType.IDENTIFIER)) {
          return _function("function");
        } else {
          Declaration out = _lambdaFunction();
          _consume(TokenType.SEMICOLON,
              "Expect ';' after lambda expresison statement");
          return out;
        }
      }

      return _statement();
    } on ParserException {
      _synchronize();
      return null;
    }
  }

  FuncDecl _function(String kind) {
    logger.finer("Parsing $kind function");
    Token id = _consume(TokenType.IDENTIFIER, "Expected $kind name");
    logger.finer("Function ID: ${id.lexeme}");
    _consume(TokenType.LEFT_PAREN, "Expected '(' after $kind name");
    List<Token> params = _parameters();
    logger.finer("Function Params: ${params.map((e) => e.lexeme).join(", ")}");
    _consume(
        TokenType.RIGHT_PAREN, "Expected ')' after function parameter list");

    _consume(TokenType.LEFT_BRACE, "Expected '{' at start of block");
    List<Declaration> body = _block();
    logger.finer("Body: ${body.prettyPrint}");
    return FuncDecl(id, params, body);
  }

  List<Token> _parameters() {
    List<Token> out = [];
    if (_match(TokenType.IDENTIFIER)) {
      out.add(_previous());
    }
    while (_match(TokenType.COMMA) && !_isAtEnd()) {
      out.add(_consume(TokenType.IDENTIFIER,
          "Expected identifier after ',' in function parameter list"));
    }

    return out;
  }

  Declaration _varDecl() {
    Token id =
        _consume(TokenType.IDENTIFIER, "Expected identifier after 'var'.");
    Expr? expr;
    if (_match(TokenType.EQUAL)) {
      expr = _expression();
    }
    _consume(TokenType.SEMICOLON, "Expected ';' after variable declaration");
    return VarDecl(id, expr);
  }

  LoxClass _classDeclaration() {
    Token id = _consume(TokenType.IDENTIFIER, "Expect class name");
    Variable? superclass;
    if (_match(TokenType.LESS)) {
      _consume(TokenType.IDENTIFIER, "Expect superclass name");
      superclass = Variable(_previous());
    }
    _consume(TokenType.LEFT_BRACE, "Expect '{' before class body");
    List<FuncDecl> methods = [];
    while (!_check(TokenType.RIGHT_BRACE) && !_isAtEnd()) {
      methods.add(_function("method"));
    }

    _consume(TokenType.RIGHT_BRACE, "Expect '}' after class body.");

    return LoxClass(id, methods, superclass: superclass);
  }

  Statement _statement() {
    logger.finer("Parsing statement");
    if (_match(TokenType.PRINT)) {
      return _printStatement();
    }

    if (_match(TokenType.LEFT_BRACE)) {
      return BlockStatement(_block());
    }

    if (_match(TokenType.IF)) {
      return _if();
    }

    if (_match(TokenType.RETURN)) {
      return _returnStatement();
    }

    if (_match([TokenType.WHILE, TokenType.FOR])) {
      _loopDepth++;
      late LoopStatement out;
      if (_match(TokenType.WHILE)) {
        out = _while();
      } else {
        out = _for();
      }
      _loopDepth--;
      return out;
    }

    if (_match(TokenType.BREAK)) {
      logger.finer("Parsing break statement, loop depth: $_loopDepth");
      if (_loopDepth == 0) {
        throw _errorRecovery(
            _previous(), "break needs to be inside of a loop.");
      }
      return BreakStatement();
    }

    return _exprStatement();
  }

  //TODO during optimazation these can be unrolled into while loops
  ForStatement _for() {
    logger.finer("Parsing for loop");
    _consume(TokenType.LEFT_PAREN, "Expected '(' after for");
    Declaration? initializer;
    if (_match(TokenType.SEMICOLON)) {
      initializer = null;
    } else if (_match(TokenType.VAR)) {
      initializer = _varDecl();
    } else {
      initializer = _exprStatement();
    }

    logger.finer("Initializer: ${initializer?.prettyPrint ?? ""}");

    Expr? condition;
    if (!_check(TokenType.SEMICOLON)) {
      condition = _expression();
    }

    logger.finer("Condition: ${condition?.prettyPrint ?? ""}");

    _consume(TokenType.SEMICOLON, "Expect ';' after loop condition");

    Expr? increment;
    if (!_check(TokenType.RIGHT_PAREN)) {
      increment = _expression();
    }

    logger.finer("Increment: ${increment?.prettyPrint ?? ""}");
    _consume(TokenType.RIGHT_PAREN, "Expect ')' after for clauses");
    Statement body = _statement();
    logger.finer("Body: ${body.prettyPrint}");

    return ForStatement(initializer, condition, increment, body);
  }

  List<Declaration> _block() {
    logger.finer("Parsing block");

    List<Declaration> out = [];
    while (!_check(TokenType.RIGHT_BRACE) && !_isAtEnd()) {
      Declaration? toAdd = _declaration();
      if (toAdd != null) {
        logger.finest("Parsed param ${toAdd.prettyPrint}");
        out.add(toAdd);
      }
    }

    logger.finer("Block body: ${out.prettyPrint}");

    _consume(TokenType.RIGHT_BRACE, "Expect '}' after block");

    return out;
  }

  IfStatement _if() {
    _consume(TokenType.LEFT_PAREN, "Expected '(' after if.");
    Expr condition = _expression();
    _consume(TokenType.RIGHT_PAREN, "Expected ')' after condition.");
    Statement ifTrue = _statement();
    Statement? ifFalse;

    if (_match(TokenType.ELSE)) {
      ifFalse = _statement();
    }
    return IfStatement(condition, ifTrue, ifFalse);
  }

  ReturnStatement _returnStatement() {
    logger.finer("Parsing return statement");
    Token keyword = _previous();
    Expr? value;
    if (!_check(TokenType.SEMICOLON)) {
      value = _expression();
    }
    logger.finer("ReturnValue: ${value?.prettyPrint ?? "nil"}");
    _consume(TokenType.SEMICOLON, "Expected ';' after return value.");
    return ReturnStatement(keyword, value);
  }

  WhileStatement _while() {
    _consume(TokenType.LEFT_PAREN, "Expected '(' after while.");
    Expr condition = _expression();
    _consume(TokenType.RIGHT_PAREN, "Expected ')' after condition.");
    Statement body = _statement();
    return WhileStatement(condition, body);
  }

  PrintStatement _printStatement() {
    logger.finer("Parsing print statement");
    Expr expr = _assignment();
    logger.finer("ToPrint: ${expr.prettyPrint}");
    _consume(TokenType.SEMICOLON, "Expect ';' after value.");
    return PrintStatement(expr);
  }

  ExprStatement _exprStatement() {
    logger.finer("Parsing expression statement");
    Expr expr = _assignment();
    logger.finer("Expr: ${expr.prettyPrint}");
    _consume(TokenType.SEMICOLON, "Expect ';' after value.");
    return ExprStatement(expr);
  }

  Expr _expression() {
    logger.finer("Parsing expression");

    if (_match(TokenType.FUN)) {
      return _lambdaFunction();
    }

    return _assignment();
  }

  LambdaFunc _lambdaFunction() {
    logger.finer("Parsing lambda function");
    _consume(TokenType.LEFT_PAREN, "Expected '(' after fun");
    List<Token> params = _parameters();
    logger.finer("Function Params: ${params.map((e) => e.lexeme).join(", ")}");
    _consume(
        TokenType.RIGHT_PAREN, "Expected ')' after function parameter list");

    _consume(TokenType.LEFT_BRACE, "Expected '{' at start of block");
    List<Declaration> body = _block();
    logger.finer("Body: ${body.prettyPrint}");
    return LambdaFunc(params, body);
  }

  Expr _assignment() {
    logger.finer("Parsing assignment");
    Expr expr = _equality();
    logger.finer("LHS: ${expr.prettyPrint}");
    // Assignment expression
    if (_match(TokenType.EQUAL)) {
      Token equals = _previous();
      Expr value = _assignment();
      if (expr is Variable) {
        logger.finer("RHS: ${expr.id.lexeme}");
        return Assignment(expr.id, value);
      } else if (expr is Get) {
        return Set(expr.object, expr.name, value);
      }
      reportError(equals, "Invalid assignment target");
    }

    // Ternary
    if (_match(TokenType.QUESTION)) {
      logger.finer("Parsing ternary expression");
      Expr trueCase = _assignment();
      _consume(TokenType.COLON, "':' expected in ternary");
      Expr falseCase = _assignment();
      return Ternary(expr, trueCase, falseCase);
    }
    return expr;
  }

  Expr _equality() {
    logger.finer("Parsing equality");
    Expr expr = _comparison();
    while (_match([TokenType.BANG_EQUAL, TokenType.EQUAL_EQUAL])) {
      Token operator = _previous();
      Expr right = _comparison();
      expr = Binary(expr, operator, right);
    }

    return expr;
  }

  Expr _comparison() {
    logger.finest("Parsing comparuson");
    Expr expr = _term();

    while (_match([
      TokenType.GREATER,
      TokenType.GREATER_EQUAL,
      TokenType.LESS,
      TokenType.LESS_EQUAL,
      TokenType.AND,
      TokenType.OR
    ])) {
      Token operator = _previous();
      Expr right = _term();
      expr = Binary(expr, operator, right);
    }
    return expr;
  }

  Expr _term() {
    logger.finest("Parsing term");
    Expr expr = _factor();
    while (_match([TokenType.PLUS, TokenType.MINUS])) {
      Token operator = _previous();
      Expr right = _factor();
      expr = Binary(expr, operator, right);
    }

    return expr;
  }

  Expr _factor() {
    logger.finest("Parsing factr");
    Expr expr = _unary();
    while (_match([TokenType.SLASH, TokenType.STAR])) {
      Token operator = _previous();
      Expr right = _unary();
      expr = Binary(expr, operator, right);
    }

    return expr;
  }

  Expr _unary() {
    logger.finest("Parsing unary");
    if (_match([TokenType.BANG, TokenType.MINUS])) {
      return Unary(_previous(), _unary());
    }
    return _call();
  }

  Call _finishCall(Expr primary) {
    Token paren = _previous();
    Call out = Call(primary, paren, _args());
    _consume(TokenType.RIGHT_PAREN, "Expected ')' after arguments.");
    return out;
  }

  Expr _call() {
    logger.finest("Parsing call");
    Expr out = _primary();
    while (true) {
      if (_match(TokenType.LEFT_PAREN)) {
        out = _finishCall(out);
      } else if (_match(TokenType.DOT)) {
        Token name =
            _consume(TokenType.IDENTIFIER, "Expect property name afte '.'.");
        out = Get(out, name);
      } else {
        break;
      }
    }
    return out;
  }

  List<Expr> _args() {
    List<Expr> out = [];
    if (!_check(TokenType.RIGHT_PAREN)) {
      out.add(_expression());
      while (_match(TokenType.COMMA)) {
        out.add(_expression());
      }
      if (out.length >= 255) {
        reportError(_peek(), "Can't have more than 255 arguments.");
      }
    }
    return out;
  }

  Expr _primary() {
    logger.finest("Parsing primary");
    if (_match(TokenType.TRUE)) return Literal(true);
    if (_match(TokenType.FALSE)) return Literal(false);
    if (_match(TokenType.NIL)) return Literal(null);
    if (_match([
      TokenType.NUMBER,
      TokenType.STRING,
    ])) {
      return Literal(_previous().literal!);
    }

    if (_match(TokenType.THIS)) {
      return This(_previous());
    }

    if (_match(TokenType.LEFT_PAREN)) {
      Expr expr = _assignment();
      _consume(TokenType.RIGHT_PAREN, "Expected ')' after expression");
      return Grouping(expr);
    }

    if (_match(TokenType.IDENTIFIER)) {
      Token name = _previous();
      return Variable(name);
    }

    if (_match(TokenType.SUPER)) {
      Token keyword = _previous();
      _consume(TokenType.DOT, "Expect '.' after 'super'");
      Token method =
          _consume(TokenType.IDENTIFIER, "Expect superclass methods name");
      return Super(keyword, method);
    }

    throw _errorRecovery(_peek(), "Expect expression.");
  }

  ParserException _errorRecovery(Token token, String message) {
    reportError(token, message);
    return ParserException();
  }

  Token _consume(TokenType type, String message) {
    if (_check(type)) return _advance();

    throw _errorRecovery(_peek(), message);
  }

  void _synchronize() {
    logger.fine("Synchronizing from ${_peek().type} @ ${_peek().line}");
    _advance();

    while (!_isAtEnd()) {
      if (_previous().type == TokenType.SEMICOLON) return;

      switch (_peek().type) {
        case TokenType.CLASS ||
              TokenType.FUN ||
              TokenType.VAR ||
              TokenType.FOR ||
              TokenType.IF ||
              TokenType.WHILE ||
              TokenType.PRINT ||
              TokenType.RETURN:
          return;
        default:
          _advance();
      }
    }
  }
}
