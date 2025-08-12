import 'package:dlox/parser/parser.dart';
import 'package:dlox/parser/tree_walkers/eval/eval.dart';
import 'package:dlox/parser/types/types.dart';
import 'package:dlox/scanner/token.dart';
import 'package:logging/logging.dart';

//TODO add unused variable detector

Logger log = Logger("DloxInterpreter.Resolver");

void _resolveVariable(Expr expr, int depth) => locals[expr] = depth;

enum ClassType { None, Class, Subclass }

ClassType _currentClass = ClassType.None;

enum FunctionType { None, Function, Initializer, Method }

FunctionType _currentFunction = FunctionType.None;

List<Map<String, bool>> scopes = [];

void _beginScope() => scopes.add({});

void _endScope() => scopes.removeLast();

void _declare(Token t) {
  log.finer("Declaring ${t.lexeme} at scope depth ${scopes.length}");
  if (scopes.isEmpty) return;
  if (scopes.last.containsKey(t.lexeme)) {
    reportError(t, "Already a variable with this in this scope");
  }
  scopes.last[t.lexeme] = false;
}

void _define(Token t) {
  log.finer("Defining ${t.lexeme} at scope depth ${scopes.length}");
  if (scopes.isEmpty) return;
  scopes.last[t.lexeme] = true;
}

void _resolveLocal(Expr expr, Token name) {
  log.finer("Resolving local ${name.lexeme} in $scopes");
  int depth = scopes.length - 1;
  for (var scope in scopes.reversed) {
    int resolveDepth = scopes.length - 1 - depth;
    log.finest("Trying to resolve ${name.lexeme} @ $resolveDepth in $scope");
    if (scope.containsKey(name.lexeme)) {
      log.finer("Local ${name.lexeme} found at scope depth $resolveDepth");
      _resolveVariable(expr, resolveDepth);
    }
    depth--;
  }
}

void _resolveFunction(LoxFunc f, FunctionType type) {
  log.finer("Resolving ${f.prettyPrint}");
  FunctionType enclosingFunction = _currentFunction;
  _currentFunction = type;
  log.finest(
      "Beginning scope for ${f is FunctionDeclaration ? f.id.lexeme : "anonymous function"}");
  _beginScope();
  log.finest(scopes);
  for (var token in f.params) {
    _declare(token);
    _define(token);
  }
  f.body.forEach(_resolve);
  log.finest(
      "Ending scope for ${f is FunctionDeclaration ? f.id.lexeme : "anonymous function"}");
  log.finest(scopes);
  _endScope();
  _currentFunction = enclosingFunction;
}

void resolve(List<LoxNode> nodes) {
  for (var n in nodes) {
    if (n is Resolvable) {
      _resolve(n as Resolvable);
    } else {
      log.finer("Cannot resolve ${n.runtimeType} skipping");
      throw "Unsupported resolve target ${n.runtimeType}";
    }
  }
}

void _resolve(Resolvable n) {
  log.finest("Resolving(${n.runtimeType}): ${(n as LoxNode).prettyPrint}");
  switch (n) {
    case BlockStatement():
      log.finest("Beginning scope for ${(n as LoxNode).prettyPrint}");
      _beginScope();
      log.finest(scopes);
      n.decls.forEach(_resolve);
      log.finest("Beginning scope for ${(n as LoxNode).prettyPrint}");
      log.finest(scopes);
      _endScope();
      break;
    case VarDecl():
      _declare(n.id);
      if (n.expr != null) {
        _resolve(n.expr!);
      }
      _define(n.id);
      break;
    case Variable():
      if (scopes.isNotEmpty && scopes.last[n.id.lexeme] == false) {
        reportError(n.id, "Can't read local variable in its own initializer");
      }
      _resolveLocal(n, n.id);
      break;
    case Assignment():
      _resolve(n.value);
      _resolveLocal(n, n.id);
      break;
    case LoxFunc():
      if (n is FunctionDeclaration) {
        _declare(n.id);
        _define(n.id);
      }

      _resolveFunction(n, FunctionType.Function);
      break;
    case ExprStatement():
      _resolve(n.expr);
      break;
    case IfStatement():
      _resolve(n.condition);
      _resolve(n.ifTrue);
      if (n.ifFalse != null) _resolve(n.ifFalse!);
      break;
    case PrintStatement():
      _resolve(n.expr);
      break;
    case ReturnStatement():
      if (_currentFunction == FunctionType.None) {
        reportError(n.keyword, "Can't return from top level code");
      }

      if (n.value != null) {
        if (_currentFunction == FunctionType.Initializer) {
          reportError(n.keyword, "Can't return a value from an initializer");
        }
        _resolve(n.value!);
      }
      break;
    case WhileStatement():
      _resolve(n.condition);
      _resolve(n.body);
      break;
    case Binary():
      _resolve(n.left);
      _resolve(n.right);
      break;
    case Call():
      _resolve(n.callee);
      n.args.forEach(_resolve);
      break;
    case Grouping():
      _resolve(n.expression);
      break;
    case Literal():
      break;
    case ForStatement():
      if (n.initializer != null) {
        _resolve(n.initializer!);
      }

      if (n.condition != null) {
        _resolve(n.condition!);
      }

      if (n.increment != null) {
        _resolve(n.increment!);
      }
      _resolve(n.body);
      break;
    case Ternary():
      _resolve(n.condition);
      _resolve(n.trueCase);
      _resolve(n.falseCase);
      break;
    case Unary():
      _resolve(n.operand);
      break;
    case BreakStatement():
      break;
    case LoxClass():
      ClassType enclosingClass = _currentClass;
      _currentClass = ClassType.Class;
      _declare(n.id);
      _define(n.id);

      if (n.superclass != null && n.id.lexeme == n.superclass!.id.lexeme) {
        reportError(n.superclass!.id, "A class can't inherit from itself");
      }

      if (n.superclass != null) {
        _currentClass = ClassType.Subclass;
        _resolve(n.superclass!);
        _beginScope();
        scopes.last["super"] = true;
      }

      log.finest("Beginning scope for ${n.id.lexeme}");
      _beginScope();
      log.finest(scopes);
      scopes.last["this"] = true;
      for (var method in n.methods) {
        FunctionType declaration = FunctionType.Method;
        if (method.id.lexeme == "init") {
          declaration = FunctionType.Initializer;
        }
        _resolveFunction(method, declaration);
      }
      log.finest("Ending scope for ${n.id.lexeme}");
      log.finest(scopes);
      _endScope();
      if (n.superclass != null) {
        _endScope();
      }
      _currentClass = enclosingClass;
      break;
    case Get():
      _resolve(n.object);
      break;
    case Set():
      _resolve(n.object);
      _resolve(n.value);
      break;
    case This():
      if (_currentClass == ClassType.None) {
        reportError(n.keyword, "Can't use 'this' outside of a class.");
      }
      _resolveLocal(n, n.keyword);
      break;
    case Super():
      if (_currentClass == ClassType.None) {
        reportError(n.keyword, "Can't use 'super' outside of a class.");
      } else if (_currentClass == ClassType.Class) {
        reportError(n.keyword, "Can't use 'super' with no superclass.");
      }
      _resolveLocal(n, n.keyword);
  }
}
