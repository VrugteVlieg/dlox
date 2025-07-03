part of "eval.dart";

class Environment {
  final Map<String, LoxValue> scope = HashMap();
  final Environment? enclosing;
  final String? _scopeName;

  Environment(
      {this.enclosing, String? scopeName, Map<String, LoxValue>? natives})
      : _scopeName = scopeName {
    if (natives != null) {
      scope.addAll(natives);
    }
  }

  String getScopeChain() {
    String out = "$scopeName: $scope";
    if (enclosing != null) {
      out = "$out < ${enclosing!.getScopeChain()}";
    }
    return out;
  }

  String get scopeName => "'${_scopeName ?? "AnonymousScope"}'";

  LoxValue define(String id, LoxValue value) {
    log.finer("Creating '$id' with value '${value.stringify()}' in $scopeName");
    log.finest("Old $scopeName: $scope");
    scope[id] = value;
    log.finest("New $scopeName: $scope");
    return null;
  }

  LoxValue assign(Token id, LoxValue value) {
    log.finer("Assigning ${value.stringify()} to ${id.lexeme} in $scopeName");
    log.finest("Elements in $scopeName: $scope");
    if (scope.containsKey(id.lexeme)) {
      log.finer("Overwriting existing value ${scope[id.lexeme]}");
      scope[id.lexeme] = value;
      return value;
    }

    if (enclosing != null) {
      log.finer(
          "$scopeName does not contain ${id.lexeme}, checking parent ${enclosing!._scopeName}");
      return enclosing!.assign(id, value);
    }

    throw RuntimeError(id, "Undefined variable '${id.lexeme}'");
  }

  LoxValue getVariable(Token id) {
    log.finer(
        "Retrieving variable ${id.lexeme} from $scopeName(${scope.entries.map((e) => "${e.key}: ${e.value}")})");
    if (scope.containsKey(id.lexeme)) {
      return scope[id.lexeme];
    }

    if (enclosing != null) {
      log.finer(
          "Variable ${id.lexeme} not found in $scopeName, checking enclosing scope");
      return enclosing!.getVariable(id);
    }

    throw RuntimeError(id, "Undefined variable '${id.lexeme}'.");
  }

  Environment _ancestor(int distance) =>
      distance == 0 ? this : enclosing!._ancestor(distance - 1);

  LoxValue getAt(int distance, String name) {
    log.finest(
        "Get @ $distance from ${_ancestor(distance)._scopeName} ${_ancestor(distance).scope} for $name");
    if (enclosing != null) {
      log.finest(getScopeChain());
    }
    return _ancestor(distance).scope[name];
  }

  LoxValue assignAt(int distance, Token id, LoxValue value) =>
      _ancestor(distance).assign(id, value);
}
