part of "types.dart";

sealed class Expr extends LoxNode implements Resolvable {
  const Expr();
}

class This extends Expr {
  final Token keyword;

  const This(this.keyword);

  @override
  String get prettyPrint => "this";
}

class Super extends Expr {
  final Token keyword;
  final Token method;

  const Super(this.keyword, this.method);

  @override
  String get prettyPrint => "super.${method.lexeme}";
}

class Assignment extends Expr {
  final Token id;
  final Expr value;
  const Assignment(this.id, this.value);

  @override
  String get prettyPrint => "${id.lexeme} = ${value.prettyPrint}";
}

class Binary extends Expr {
  final Expr left;
  final Token operator;
  final Expr right;

  const Binary(this.left, this.operator, this.right);

  @override
  String get prettyPrint =>
      "${left.prettyPrint} ${operator.lexeme} ${right.prettyPrint}";
}

class Grouping extends Expr {
  final Expr expression;

  const Grouping(this.expression);

  @override
  String get prettyPrint => parenthesize("group", [expression]);
}

class Literal extends Expr {
  final Object? value;
  const Literal(this.value);

  @override
  String get prettyPrint => value.stringify();
}

class Unary extends Expr {
  final Token operator;
  final Expr operand;
  const Unary(this.operator, this.operand);

  @override
  String get prettyPrint => parenthesize(operator.lexeme, [operand]);
}

class Call extends Expr {
  final Expr callee;
  final Token paren;
  final List<Expr> args;
  const Call(this.callee, this.paren, this.args);

  @override
  String get prettyPrint => "${callee.prettyPrint}(${args.map(
        (e) => e.prettyPrint,
      ).join(", ")})";
}

class Get extends Expr {
  final Expr object;
  final Token name;

  const Get(this.object, this.name);

  @override
  String get prettyPrint => "${object.toString()}.${name.lexeme}";
}

class Set extends Expr {
  final Expr object;
  final Token name;
  final Expr value;
  const Set(this.object, this.name, this.value);

  @override
  String get prettyPrint =>
      "${object.prettyPrint}.${name.lexeme} = ${value.prettyPrint}";
}

class Ternary extends Expr {
  final Expr condition;
  final Expr trueCase;
  final Expr falseCase;

  const Ternary(this.condition, this.trueCase, this.falseCase);

  @override
  String get prettyPrint =>
      "${condition.prettyPrint} ? ${trueCase.prettyPrint} : ${falseCase.prettyPrint}";
}

class Variable extends Expr {
  final Token id;

  const Variable(this.id);

  @override
  String get prettyPrint => id.lexeme;
}
