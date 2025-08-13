import 'package:dlox/parser/tree_walkers/eval/eval.dart';
import 'package:dlox/scanner/token.dart';
part "expr.dart";
part "statement.dart";

sealed class LoxNode {
  const LoxNode();

  @override
  String toString() => prettyPrint;

  String get prettyPrint;
}

String parenthesize(String name, List<Expr> exprs) =>
    "($name ${exprs.map((e) => e.prettyPrint).join(" ")})";

extension StringifyNode on LoxValue {
  String stringify() {
    return switch (this) {
      null => "nil",
      int i => i.toString(),
      double d => d.toString(),
      String s => "\"$s\"",
      var v => v.toString()
    };
  }
}

extension PrettyPrint on List<LoxNode> {
  String get prettyPrint => map((e) => e.prettyPrint).join("\n");
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

  @override
  String get prettyPrint => expr != null
      ? "var ${id.lexeme} = ${expr!.prettyPrint};"
      : "var ${id.lexeme};";
}

sealed class FunctionDeclaration extends LoxFunc {
  final Token id;

  const FunctionDeclaration(this.id, super.params, super.body);
}

class MethodDecl extends FunctionDeclaration {
  const MethodDecl(super.id, super.params, super.body);

  @override
  String get prettyPrint =>
      "${id.lexeme}(${params.map((e) => e.lexeme).join(", ")}) {\n${body.prettyPrint}\n}";
}

class FuncDecl extends FunctionDeclaration {
  const FuncDecl(super.id, super.params, super.body);

  @override
  String get prettyPrint =>
      "fun ${id.lexeme}(${params.map((e) => e.lexeme).join(", ")}) {\n${body.prettyPrint}\n}";
}

class LambdaFunc extends LoxFunc implements Expr {
  bool isExprStatement = false;
  LambdaFunc(super.params, super.body);

  @override
  String get prettyPrint =>
      "fun (${params.map((e) => e.lexeme).join(", ")}) {\n${body.prettyPrint}\n}${isExprStatement ? ";" : ""}";
}

class LoxClass implements Declaration {
  final Token id;
  final Variable? superclass;
  final List<FunctionDeclaration> methods;

  const LoxClass(this.id, this.methods, {this.superclass});

  @override
  String get prettyPrint =>
      "class ${id.lexeme}${superclass == null ? "" : " < ${superclass!.id.lexeme}"} {\n${methods.map(
            (e) => e.prettyPrint,
          ).join("\n\n")}\n}";
}
