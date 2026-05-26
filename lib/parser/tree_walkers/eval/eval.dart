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

Future<void> execute(List<LoxNode> program) async {
  for (var statement in program) {
    await _eval(statement);
  }
}

typedef LoxValue = Object?;

final Environment globalScope = Environment(
  scopeName: "GlobalScope",
  natives: {"clock": Clock()},
);

List<Environment> scopeStack = [globalScope];
Environment get _currentScope => scopeStack.last;

Future<LoxValue> _eval(LoxNode n) async {
  return switch (n) {
    Binary() => _binary(n),
    Grouping() => await _eval(n.expression),
    Literal() => n.value,
    Unary() => switch ((n.operator.type, await _eval(n.operand))) {
      (.BANG, bool val) => !val.isTruthy,
      (.MINUS, double val) => -1 * val,
      (var t, var val) => throw RuntimeError(
        n.operator,
        "Unsupported Unary operation $t $val(${val.runtimeType})",
      ),
    },
    Ternary() =>
      (await _eval(n.condition)).isTruthy ? await _eval(n.trueCase) : await _eval(n.falseCase),
    ExprStatement() => await _eval(n.expr),
    PrintStatement() => await _print(n),
    ReadStatement() => await _read(n),
    VarDecl() => _currentScope.define(n.id.lexeme, n.expr.map((n) async => await _eval(n))),
    Variable() => _lookupVariable(n.id, n),
    Assignment() =>
      locals.containsKey(n)
          ? _currentScope.assignAt(locals[n]!, n.id, await _eval(n.value))
          : globalScope.assign(n.id, await _eval(n.value)),
    BlockStatement() => _executeBlock(
      n.decls,
      Environment(enclosing: _currentScope, scopeName: "Anonymous scope"),
    ),
    IfStatement() => _if(n),
    LoopStatement() => _loopStatement(n),
    BreakStatement() => throw n,
    Call() => _call(n),
    FunctionDeclaration() => _funcDecl(n),
    ReturnStatement() => _returnStatement(n),
    LambdaFunc() => LoxFunction(
      LambdaFunc(n.params, n.body),
      _currentScope,
      false,
    ),
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

Future<LoxValue> _setExpr(Set s) async {
  LoxValue object = await _eval(s.object);
  if (object is! LoxInstance) {
    throw RuntimeError(s.name, "Only instances have fields");
  }

  LoxValue val = await _eval(s.value);
  object.set(s.name, val);
  return null;
}

Future<LoxValue> _getExpr(Get g) async {
  log.finer("Eval Get ${g.prettyPrint}");
  LoxValue val = await _eval(g.object);
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

Future<LoxValue> _classDecl(LoxClass c) async {
  LoxValue superclass;
  log.finest("Evaluating ${c.prettyPrint}");
  if (c.superclass != null) {
    superclass = await _eval(c.superclass!);
    if (superclass is! LoxKlass) {
      throw RuntimeError(
        c.superclass!.id,
        "Superclass must be a class is ${superclass.runtimeType}",
      );
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
    methods[method.id.lexeme] = LoxFunction(
      method,
      _currentScope,
      method.id.lexeme == "init",
    );
  }
  LoxKlass klass = LoxKlass(
    c.id.lexeme,
    methods,
    superclass: (superclass == null) ? null : superclass as LoxKlass,
  );
  if (superclass != null) {
    scopeStack.last = _currentScope.enclosing!;
  }
  _currentScope.assign(c.id, klass);
  return null;
}

Future<LoxValue> _call(Call c) async {
  log.fine("Calling $c");
  LoxValue callee = await _eval(c.callee);
  List<LoxValue> args = c.args.map((a) async => await _eval(a)).toList();
  if (callee is! LoxCallable) {
    throw RuntimeError(c.paren, "Can only call functions and classes found ${callee.runtimeType}");
  } else if (callee.arity() != args.length) {
    throw RuntimeError(
      c.paren,
      "Expected ${callee.arity()} arguments but got ${args.length}.",
    );
  } else {
    return callee.call(_currentScope, args);
  }
}

LoxValue _loopStatement(LoopStatement l) {
  try {
    return switch (l) {
      WhileStatement() => _while(l),
      ForStatement() => _for(l),
    };
  } on BreakStatement {
    return null;
  }
}

Future<LoxValue> _for(ForStatement f) async {
  for (
    f.initializer.map((i) async => await _eval(i));
    f.condition.map((c) async => await _eval(c)).isTruthy;
    f.increment.map((i) async => await _eval(i))
  ) {
    await _eval(f.body);
  }
  return null;
}

Future<LoxValue> _binary(Binary b) async {
  switch (b.operator.type) {
    case .AND:
      LoxValue left = await _eval(b.left);
      return left.isTruthy ? await _eval(b.right) : left;
    case .OR:
      LoxValue left = await _eval(b.left);
      return left.isTruthy ? left : await _eval(b.right);
    default:
      return switch ((await _eval(b.left), b.operator.type, await _eval(b.right))) {
        (double l, .SLASH, double r) =>
          r == 0
              ? throw RuntimeError(b.operator, "Division by zero is not cool")
              : l / r,
        (double l, .STAR, double r) => l * r,
        (double l, .PLUS, double r) => l + r,
        (double l, .MINUS, double r) => l - r,
        (String l, .PLUS, var r) => "$l${r.stringify()}",
        (var l, .PLUS, String r) => "${l.stringify()}$r",
        (String l, .STAR, double r) => List.filled(
          r.floor(),
          l,
        ).join(),
        (double l, .STAR, String r) => List.filled(
          l.floor(),
          r,
        ).join(),
        (var l, .BANG_EQUAL, var r) => !isEqual(l, r),
        (var l, .EQUAL_EQUAL, var r) => isEqual(l, r),
        (double l, .GREATER, double r) => l > r,
        (double l, .GREATER_EQUAL, double r) => l >= r,
        (double l, .LESS, double r) => l < r,
        (double l, .LESS_EQUAL, double r) => l <= r,
        (var l, var t, var r) => throw RuntimeError(
          b.operator,
          "Unsupport operation $l(${l.runtimeType}) $t $r(${r.runtimeType})",
        ),
      };
  }
}

Future<LoxValue> _while(WhileStatement w) async {
  while ((await _eval(w.condition)).isTruthy) {
    await _eval(w.body);
  }
  return null;
}

Future<LoxValue> _read(ReadStatement n) async {
  String varName;
  log.info("Read statement with ${n.target.runtimeType}");
  String input = await runtime.readStdIn();
  log.info("Read $input in func");
  switch (n.target) {
    case VarDecl(:var id):
    log.info("Vardecl");
      varName = id.lexeme;
      _currentScope.define(varName, input);
    case Variable(:var id):
    log.info("Variable");
      varName = id.lexeme;
      locals.containsKey(n.target)
          ? _currentScope.assignAt(locals[n.target]!, id, input)
          : globalScope.assign(id, input);
  }
  log.info("Read $input into $varName");
  return null;
}

Future<LoxValue> _print(PrintStatement n) async {
      Object? toPrint = await _eval(n.expr);
      log.finer("Printing ${toPrint.stringify()}(${toPrint.runtimeType})");
      runtime.writeStdOut(toPrint);
      return null;
    }

Future<LoxValue> _if(IfStatement n)async {
  if ((await _eval(n.condition)).isTruthy) {
    return await _eval(n.ifTrue);
  } else if (n.ifFalse != null) {
    return await _eval(n.ifFalse!);
  }
  return null;
}

Future<LoxValue> _executeBlock(
  List<Declaration> body,
  Environment executionEnvironment,
) async {
  scopeStack.add(executionEnvironment);
  for (Declaration stmt in body) {
    await _eval(stmt);
  }
  scopeStack.removeLast();
  return null;
}

Future<LoxValue> _returnStatement(ReturnStatement r) async {
  LoxValue value;
  if (r.value != null) {
    value = await _eval(r.value!);
  }
  log.finer("Returning ${value.stringify()}");
  throw Return(value);
}

extension on Object? {
  bool get isTruthy => switch (this) {
    null => false,
    bool b => b,
    _ => true,
  };
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
          "Undefined property access ${name.lexeme} on $this, defined properties(${fields.length}): [${fields.keys.join(", ")}]",
        );
        return throw RuntimeError(name, "Undefined property ${name.lexeme}.");
      }
    }
  }

  void set(Token name, LoxValue val) {
    fields[name.lexeme] = val;
  }
}

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
    Environment functionScope = Environment(
      enclosing: declScope,
      scopeName: "$_id scope",
    );
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
