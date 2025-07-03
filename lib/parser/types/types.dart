import 'package:dlox/parser/tree_walkers/pretty_print/pretty_print.dart';
import 'package:dlox/scanner/token.dart';
part "expr.dart";
part "statement.dart";

sealed class LoxNode {
  const LoxNode();

  @override
  String toString() => prettyPrintProgram([this]);
}

sealed class Resolvable {}

sealed class Declaration extends LoxNode implements Resolvable {
  const Declaration();
}

sealed class LoxFunc extends LoxNode implements Declaration {
  final List<Token> params;
  final List<Declaration> body;
  const LoxFunc(this.params, this.body);
}

class VarDecl extends Declaration {
  final Token id;
  final Expr? expr;
  const VarDecl(this.id, this.expr);
}

class FuncDecl extends LoxFunc {
  final Token id;

  const FuncDecl(this.id, super.params, super.body);
}

class LambdaFunc extends LoxFunc implements Expr {
  const LambdaFunc(super.params, super.body);
}

class LoxClass implements Declaration {
  final Token id;
  final Variable? superclass;
  final List<FuncDecl> methods;

  const LoxClass(this.id, this.methods, {this.superclass});
}
