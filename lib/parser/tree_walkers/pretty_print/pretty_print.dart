import 'package:dlox/parser/types/types.dart';
import 'package:dlox/scanner/token.dart';

String prettyPrintProgram(List<LoxNode> program) {
  return program.map(_prettyPrintNode).join("\n");
}

extension PrettyPrint on LoxNode {
  String get prettyPrint => _prettyPrintNode(this);
}

String _prettyPrintNode(LoxNode toPrint) {
  switch (toPrint) {
    case Binary(left: Expr left, operator: Token operator, right: Expr right):
      return "${left.prettyPrint} ${operator.lexeme} ${right.prettyPrint}";
    case Grouping(expression: Expr expr):
      return _parenthesize("group", [expr]);
    case Literal():
      return toPrint.value.stringify();
    case Unary():
      return _parenthesize(toPrint.operator.lexeme, [toPrint.operand]);
    case Ternary():
      return "${toPrint.condition.prettyPrint} ? ${toPrint.trueCase.prettyPrint} : ${toPrint.falseCase.prettyPrint}";
    case ExprStatement():
      return "${toPrint.expr.prettyPrint};";
    case PrintStatement():
      return "print ${toPrint.expr.prettyPrint};";
    case VarDecl():
      return () {
        if (toPrint.expr != null) {
          return "var ${toPrint.id.lexeme} = ${toPrint.expr!.prettyPrint};";
        } else {
          return "var ${toPrint.id.lexeme};";
        }
      }();
    case Variable():
      return toPrint.id.lexeme;
    case Assignment():
      return "${toPrint.id.lexeme} = ${toPrint.value.prettyPrint}";
    case BlockStatement():
      return "{\n${toPrint.decls.map(_prettyPrintNode).join("\n")}\n}";
    case IfStatement():
      return "if(${toPrint.condition.prettyPrint}) ${toPrint.ifTrue.prettyPrint}${toPrint.ifFalse != null ? " else ${toPrint.ifFalse!.prettyPrint}" : ""}";
    case WhileStatement():
      return "while(${toPrint.condition.prettyPrint}) ${toPrint.body.prettyPrint}";
    case ForStatement():
      return "for(${toPrint.initializer?.prettyPrint ?? ";"}${toPrint.condition?.prettyPrint ?? ""};${toPrint.increment?.prettyPrint ?? ""}) ${toPrint.body.prettyPrint}";
    case BreakStatement():
      return "break;";
    case Call():
      return "${toPrint.callee.prettyPrint}(${toPrint.args.map(_prettyPrintNode).join(", ")})";
    case FuncDecl():
      return "fun ${toPrint.id.lexeme}(${toPrint.params.map((e) => e.lexeme).join(", ")}) ${prettyPrintProgram(toPrint.body)}";
    case ReturnStatement():
      return "return${toPrint.value == null ? "" : " ${toPrint.value?.prettyPrint ?? ""}"};";
    case LambdaFunc():
      return "fun (${toPrint.params.map((e) => e.lexeme).join(", ")}) ${prettyPrintProgram(toPrint.body)}";
    case LoxClass():
      return "class ${toPrint.id.lexeme}${toPrint.superclass == null ? "" : " < ${toPrint.superclass!.id.lexeme}"} {\n${toPrint.methods.map(_prettyPrintNode).join("\n\n")}\n}";
    case Get():
      return "${_prettyPrintNode(toPrint.object)}.${toPrint.name.lexeme}";
    case Set():
      return "${toPrint.object.prettyPrint}.${toPrint.name.lexeme} = ${toPrint.value.prettyPrint}";
    case This():
      return "this";
    case Super():
      return "super.${toPrint.method.lexeme}";
  }
}

String _parenthesize(String name, List<Expr> exprs) =>
    "($name ${exprs.map(_prettyPrintNode).join(" ")})";

extension StringifyNode on Object? {
  String stringify() {
    return switch (this) {
      null => "nil",
      int i => i.toString(),
      double d => d.toString(),
      var v => v.toString()
    };
  }
}
