part of "types.dart";

sealed class Statement extends Declaration {
  const Statement();
}

class ExprStatement extends Statement {
  final Expr expr;
  const ExprStatement(this.expr);

  @override
  String get prettyPrint => "${expr.prettyPrint};";
}

class PrintStatement extends Statement {
  final Expr expr;
  const PrintStatement(this.expr);

  @override
  String get prettyPrint => "print ${expr.prettyPrint};";
}

class ReturnStatement extends Statement {
  final Expr? value;
  final Token keyword;
  const ReturnStatement(this.keyword, this.value);

  @override
  String get prettyPrint =>
      "return${value == null ? "" : " ${value?.prettyPrint ?? ""}"};";
}

//TODO not sure if this is even needed, caused a bunch of kak during resolution
class BlockStatement extends Statement {
  final List<Declaration> decls;
  const BlockStatement(this.decls);

  @override
  String get prettyPrint => "{\n${decls.map(
        (e) => e.prettyPrint,
      ).join("\n")}\n}";
}

class IfStatement extends Statement {
  final Expr condition;
  final Statement ifTrue;
  final Statement? ifFalse;

  const IfStatement(this.condition, this.ifTrue, this.ifFalse);

  @override
  String get prettyPrint =>
      "if(${condition.prettyPrint}) ${ifTrue.prettyPrint}${ifFalse != null ? " else ${ifFalse!.prettyPrint}" : ""}";
}

class BreakStatement extends Statement {
  const BreakStatement();

  @override
  String get prettyPrint => "break";
}

sealed class LoopStatement extends Statement {
  const LoopStatement();
}

class WhileStatement extends LoopStatement {
  final Expr condition;
  final Statement body;

  const WhileStatement(this.condition, this.body);

  @override
  String get prettyPrint =>
      "while(${condition.prettyPrint}) ${body.prettyPrint}";
}

class ForStatement extends LoopStatement {
  final Declaration? initializer;
  final Expr? condition;
  final Expr? increment;
  final Statement body;
  const ForStatement(
      this.initializer, this.condition, this.increment, this.body);

  @override
  String get prettyPrint =>
      "for(${initializer?.prettyPrint ?? ";"}${condition?.prettyPrint ?? ""};${increment?.prettyPrint ?? ""}) ${body.prettyPrint}";
}
