part of "types.dart";

sealed class Statement extends Declaration {
  const Statement();
}

class ExprStatement extends Statement {
  final Expr expr;
  const ExprStatement(this.expr);
}

class PrintStatement extends Statement {
  final Expr expr;
  const PrintStatement(this.expr);
}

class ReturnStatement extends Statement {
  final Expr? value;
  final Token keyword;
  const ReturnStatement(this.keyword, this.value);
}

//TODO not sure if this is even needed, caused a bunch of kak during resolution
class BlockStatement extends Statement {
  final List<Declaration> decls;
  const BlockStatement(this.decls);
}

class IfStatement extends Statement {
  final Expr condition;
  final Statement ifTrue;
  final Statement? ifFalse;

  const IfStatement(this.condition, this.ifTrue, this.ifFalse);
}

class BreakStatement extends Statement {
  const BreakStatement();
}

sealed class LoopStatement extends Statement {
  const LoopStatement();
}

class WhileStatement extends LoopStatement {
  final Expr condition;
  final Statement body;

  const WhileStatement(this.condition, this.body);
}

class ForStatement extends LoopStatement {
  final Declaration? initializer;
  final Expr? condition;
  final Expr? increment;
  final Statement body;
  const ForStatement(
      this.initializer, this.condition, this.increment, this.body);
}
