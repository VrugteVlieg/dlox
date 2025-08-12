import 'dart:collection';

import 'package:dlox/dlox.dart';
import 'package:dlox/parser/types/types.dart';
import 'package:dlox/scanner/token.dart';
import 'package:logging/logging.dart';

part "environment.dart";
part "error.dart";

Logger log = Logger("DloxInterpreter.Eval");

bool isEqual(Object? l, Object? r) {
  if (l == null && r == null) return true;
  if (l == null) return false;

  return l == r;
}

Map<Expr, int> locals = {};

LoxValue _lookupVariable(Token name, Expr expr) {
  log.finest("Lookup ${name.lexeme} in\n$locals\n for $expr");
  final out = locals.containsKey(expr)
      ? _currentScope.getAt(locals[expr]!, name.lexeme)
      : globalScope.getVariable(name);
  log.finest("Found $out");
  return out;
}

void execute(List<LoxNode> program) {
  program.forEach(_eval);
}

typedef LoxValue = Object?;

final Environment globalScope =
    Environment(scopeName: "GlobalScope", natives: {"clock": Clock()});

List<Environment> scopeStack = [globalScope];
Environment get _currentScope => scopeStack.last;

LoxValue _eval(LoxNode n) {
  log.finer("Evaluating ${n.prettyPrint}(${n.runtimeType})");
  return switch (n) {
    Binary() => _binary(n),
    Grouping() => _eval(n.expression),
    Literal() => n.value,
    Unary() => switch ((n.operator.type, _eval(n.operand))) {
        (TokenType.BANG, bool val) => !val.isTruthy,
        (TokenType.MINUS, double val) => -1 * val,
        (var t, var val) => throw RuntimeError(n.operator,
            "Unsupported Unary operation $t $val(${val.runtimeType})"),
      },
    Ternary() =>
      _eval(n.condition).isTruthy ? _eval(n.trueCase) : _eval(n.falseCase),
    ExprStatement() => _eval(n.expr),
    PrintStatement() => () {
        Object? toPrint = _eval(n.expr);
        log.finer("Printing ${toPrint.stringify()}(${toPrint.runtimeType})");
        runtime.writeStdOut(toPrint);
      }(),
    VarDecl() => _currentScope.define(n.id.lexeme, n.expr.map(_eval)),
    Variable() => _lookupVariable(n.id, n),
    Assignment() => locals.containsKey(n)
        ? _currentScope.assignAt(locals[n]!, n.id, _eval(n.value))
        : globalScope.assign(n.id, _eval(n.value)),
    BlockStatement() => _executeBlock(n.decls,
        Environment(enclosing: _currentScope, scopeName: "Anonymous scope")),
    IfStatement() => _if(n),
    LoopStatement() => _loopStatement(n),
    BreakStatement() => throw n,
    Call() => _call(n),
    FunctionDeclaration() => _funcDecl(n),
    ReturnStatement() => _returnStatement(n),
    LambdaFunc() =>
      LoxFunction(LambdaFunc(n.params, n.body), _currentScope, false),
    LoxClass() => _classDecl(n),
    Get() => _getExpr(n),
    Set() => _setExpr(n),
    This() => _lookupVariable(n.keyword, n),
    Super() => _superExpr(n),
  };
}

LoxValue _superExpr(Super s) {
  int distance = locals[s]!;
  LoxKlass superclass = _currentScope.getAt(distance, "super") as LoxKlass;

  LoxInstance object = _currentScope.getAt(distance - 1, "this") as LoxInstance;

  LoxFunction? out = superclass.findMethod(s.method.lexeme)?.bind(object);

  if (out == null) {
    throw RuntimeError(s.method, "Undefined property '${s.method.lexeme}'");
  }

  return out;
}

LoxValue _setExpr(Set s) {
  LoxValue object = _eval(s.object);
  if (object is! LoxInstance) {
    throw RuntimeError(s.name, "Only instances have fields");
  }

  LoxValue val = _eval(s.value);
  object.set(s.name, val);
  return null;
}

LoxValue _getExpr(Get g) {
  log.finer("Eval Get ${g.prettyPrint}");
  LoxValue val = _eval(g.object);
  log.finer("${val.runtimeType}${val.stringify()}${val.toString()}");
  if (val is LoxInstance) {
    return val.get(g.name);
  }

  throw RuntimeError(g.name, "Only instances have properties");
}

LoxValue _funcDecl(FunctionDeclaration f) {
  _currentScope.define(f.id.lexeme, LoxFunction(f, _currentScope, false));
  return null;
}

LoxValue _classDecl(LoxClass c) {
  LoxValue superclass;
  log.finest("Evaluating ${c.prettyPrint}");
  if (c.superclass != null) {
    superclass = _eval(c.superclass!);
    if (superclass is! LoxKlass) {
      throw RuntimeError(c.superclass!.id,
          "Superclass must be a class is ${superclass.runtimeType}");
    }
    log.finest("${c.id.lexeme} has ${superclass.name} as super class");
  }

  _currentScope.define(c.id.lexeme, null);

  if (c.superclass != null) {
    scopeStack.last = Environment(enclosing: scopeStack.last)
      ..define("super", superclass);
  }
  Map<String, LoxFunction> methods = {};
  for (var method in c.methods) {
    methods[method.id.lexeme] =
        LoxFunction(method, _currentScope, method.id.lexeme == "init");
  }
  LoxKlass klass = LoxKlass(c.id.lexeme, methods,
      superclass: (superclass == null) ? null : superclass as LoxKlass);
  if (superclass != null) {
    scopeStack.last = _currentScope.enclosing!;
  }
  _currentScope.assign(c.id, klass);
  return null;
}

LoxValue _call(Call c) {
  LoxValue callee = _eval(c.callee);
  List<LoxValue> args = c.args.map(_eval).toList();
  if (callee is! LoxCallable) {
    throw RuntimeError(c.paren, "Can only call functions and classes.");
  } else if (callee.arity() != args.length) {
    throw RuntimeError(c.paren,
        "Expected ${callee.arity()} arguments but got ${args.length}.");
  } else {
    return callee.call(_currentScope, args);
  }
}

LoxValue _loopStatement(LoopStatement l) {
  try {
    return switch (l) {
      WhileStatement() => _while(l),
      ForStatement() => _for(l)
    };
  } on BreakStatement {
    return null;
  }
}

LoxValue _for(ForStatement f) {
  for (f.initializer.map(_eval);
      f.condition.map(_eval).isTruthy;
      f.increment.map(_eval)) {
    _eval(f.body);
  }
  return null;
}

LoxValue _binary(Binary b) {
  switch (b.operator.type) {
    case TokenType.AND:
      LoxValue left = _eval(b.left);
      return left.isTruthy ? _eval(b.right) : left;
    case TokenType.OR:
      LoxValue left = _eval(b.left);
      return left.isTruthy ? left : _eval(b.right);
    default:
      return switch ((_eval(b.left), b.operator.type, _eval(b.right))) {
        (double l, TokenType.SLASH, double r) => r == 0
            ? throw RuntimeError(b.operator, "Division by zero is not cool")
            : l / r,
        (double l, TokenType.STAR, double r) => l * r,
        (double l, TokenType.PLUS, double r) => l + r,
        (double l, TokenType.MINUS, double r) => l - r,
        (String l, TokenType.PLUS, var r) => "$l${r.stringify()}",
        (var l, TokenType.PLUS, String r) => "${l.stringify()}$r",
        (String l, TokenType.STAR, double r) =>
          List.filled(r.floor(), l).join(),
        (double l, TokenType.STAR, String r) =>
          List.filled(l.floor(), r).join(),
        (var l, TokenType.BANG_EQUAL, var r) => !isEqual(l, r),
        (var l, TokenType.EQUAL_EQUAL, var r) => isEqual(l, r),
        (double l, TokenType.GREATER, double r) => l > r,
        (double l, TokenType.GREATER_EQUAL, double r) => l >= r,
        (double l, TokenType.LESS, double r) => l < r,
        (double l, TokenType.LESS_EQUAL, double r) => l <= r,
        (var l, var t, var r) => throw RuntimeError(b.operator,
            "Unsupport operation $l(${l.runtimeType}) $t $r(${r.runtimeType})"),
      };
  }
}

LoxValue _while(WhileStatement w) {
  while (_eval(w.condition).isTruthy) {
    _eval(w.body);
  }
  return null;
}

LoxValue _if(IfStatement n) {
  if (_eval(n.condition).isTruthy) {
    return _eval(n.ifTrue);
  } else if (n.ifFalse != null) {
    return _eval(n.ifFalse!);
  }
  return null;
}

LoxValue _executeBlock(
    List<Declaration> body, Environment executionEnvironment) {
  scopeStack.add(executionEnvironment);
  for (Declaration stmt in body) {
    _eval(stmt);
  }
  scopeStack.removeLast();
  return null;
}

LoxValue _returnStatement(ReturnStatement r) {
  LoxValue value;
  if (r.value != null) {
    value = _eval(r.value!);
  }
  log.finer("Returning ${value.stringify()}");
  throw Return(value);
}

extension on Object? {
  bool get isTruthy => switch (this) { null => false, bool b => b, _ => true };
}

extension<T> on T? {
  M? map<M>(M? Function(T) mapper) {
    final self = this;
    return self == null ? null : mapper(self);
  }
}

class LoxKlass implements LoxCallable {
  final String name;
  final LoxKlass? superclass;
  final Map<String, LoxFunction> methods;

  LoxFunction? findMethod(String name) =>
      methods[name] ?? superclass?.findMethod(name);

  @override
  String toString() => name;

  const LoxKlass(this.name, this.methods, {this.superclass});

  @override
  int arity() => findMethod("init")?.arity() ?? 0;

  @override
  LoxValue? call(Environment env, List<LoxValue?> args) {
    LoxInstance out = LoxInstance(this);
    LoxFunction? init = findMethod("init");
    if (init != null) {
      init.bind(out).call(env, args);
    }
    return out;
  }
}

class LoxInstance {
  final LoxKlass _klass;
  final Map<String, LoxValue> fields = {};

  LoxInstance(this._klass);

  @override
  String toString() => "${_klass.name} instance";

  LoxValue get(Token name) {
    if (fields.containsKey(name.lexeme)) {
      return fields[name.lexeme];
    } else {
      LoxFunction? method = _klass.findMethod(name.lexeme);
      if (method != null) {
        return method.bind(this);
      } else {
        log.finer(
            "Undefined property access ${name.lexeme} on $this, defined properties(${fields.length}): [${fields.keys.join(", ")}]");
        return throw RuntimeError(name, "Undefined property ${name.lexeme}.");
      }
    }
  }

  void set(Token name, LoxValue val) {
    fields[name.lexeme] = val;
  }
}

//TODO this can probs be replace by just throwing the LoxValue
class Return {
  final LoxValue value;

  Return(this.value);
}

class Clock implements LoxCallable {
  @override
  int arity() => 0;

  @override
  LoxValue? call(Environment env, List<LoxValue?> args) =>
      DateTime.now().millisecondsSinceEpoch;
}

class LoxFunction implements LoxCallable {
  final Environment declScope;
  final LoxFunc declaration;
  final bool isInitializer;

  const LoxFunction(this.declaration, this.declScope, this.isInitializer);

  String get _id => switch (declaration) {
        FunctionDeclaration(id: var id) => id.lexeme,
        LambdaFunc() => "lambda",
      };

  /// Create a wrapping scope containing a reference `instance` under `this`
  LoxFunction bind(LoxInstance instance) {
    Environment environment = Environment(enclosing: declScope);
    environment.define("this", instance);
    return LoxFunction(declaration, environment, isInitializer);
  }

  @override
  int arity() => declaration.params.length;

  @override
  LoxValue call(Environment env, List<LoxValue?> args) {
    Environment functionScope =
        Environment(enclosing: declScope, scopeName: "$_id scope");
    for (var (i, e) in declaration.params.indexed) {
      functionScope.define(e.lexeme, args[i]);
    }
    try {
      _executeBlock(declaration.body, functionScope);
    } on Return catch (r) {
      scopeStack.removeLast();
      if (isInitializer) return declScope.getAt(0, "this");
      return r.value;
    }
    if (isInitializer) {
      log.finest("Calling constructor, returning this");
      return declScope.getAt(0, "this");
    }
    return null;
  }

  @override
  String toString() => "<fn $_id>";
}

sealed class LoxCallable {
  LoxValue call(Environment env, List<LoxValue> args);
  int arity();

  @override
  String toString() => "<native fn>";
}
