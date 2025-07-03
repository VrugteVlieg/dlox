part of "types.dart";

sealed class Expr extends LoxNode implements Resolvable {
  const Expr();
}

class This extends Expr {
  final Token keyword;

  const This(this.keyword);
}

class Super extends Expr {
  final Token keyword;
  final Token method;

  const Super(this.keyword, this.method);
}

class Assignment extends Expr {
  final Token id;
  final Expr value;
  const Assignment(this.id, this.value);
}

class Binary extends Expr {
  final Expr left;
  final Token operator;
  final Expr right;

  const Binary(this.left, this.operator, this.right);
}

class Grouping extends Expr {
  final Expr expression;

  const Grouping(this.expression);
}

class Literal extends Expr {
  final Object? value;
  const Literal(this.value);
}

class Unary extends Expr {
  final Token operator;
  final Expr operand;
  const Unary(this.operator, this.operand);
}

class Call extends Expr {
  final Expr callee;
  final Token paren;
  final List<Expr> args;
  const Call(this.callee, this.paren, this.args);
}

class Get extends Expr {
  final Expr object;
  final Token name;

  const Get(this.object, this.name);
}

class Set extends Expr {
  final Expr object;
  final Token name;
  final Expr value;
  const Set(this.object, this.name, this.value);
}

class Ternary extends Expr {
  final Expr condition;
  final Expr trueCase;
  final Expr falseCase;

  const Ternary(this.condition, this.trueCase, this.falseCase);
}

class Variable extends Expr {
  final Token id;

  const Variable(this.id);
}
