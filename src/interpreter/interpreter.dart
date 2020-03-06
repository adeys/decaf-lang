import '../ast/expression.dart';
import '../ast/statement.dart';
import '../symbol/symbol.dart';
import 'environmnent.dart';
import 'value.dart';

class Interpreter implements StmtVisitor, ExprVisitor {
  SymbolTable symbols;
  Environment _env;

  Interpreter(this.symbols) {
    _env = new Environment();
  }

  Value evaluate(List<Stmt> ast) {
    Value result;
    for (Stmt stmt in ast) {
      result = _execute(stmt);
    }

    return result;
  }

  Value _execute(Stmt stmt) {
    return stmt.accept(this);
  }

  Value _evaluate(Expr expr) {
    return expr.accept(this);
  }

  @override
  visitAssignExpr(AssignExpr expr) {
    // TODO: implement visitAssignExpr
    return null;
  }

  @override
  visitBinaryExpr(BinaryExpr expr) {
    // TODO: implement visitBinaryExpr
    return null;
  }

  @override
  visitBlockStmt(BlockStmt stmt) {
    // TODO: implement visitBlockStmt
    return null;
  }

  @override
  visitBreakStmt(BreakStmt stmt) {
    // TODO: implement visitBreakStmt
    return null;
  }

  @override
  visitCallExpr(CallExpr expr) {
    // TODO: implement visitCallExpr
    return null;
  }

  @override
  visitExpressionStmt(ExpressionStmt stmt) {
    // TODO: implement visitExpressionStmt
    return null;
  }

  @override
  visitForStmt(ForStmt stmt) {
    // TODO: implement visitForStmt
    return null;
  }

  @override
  visitFunctionStmt(FunctionStmt stmt) {
    // TODO: implement visitFunctionStmt
    return null;
  }

  @override
  visitGroupingExpr(GroupingExpr expr) {
    // TODO: implement visitGroupingExpr
    return null;
  }

  @override
  visitIfStmt(IfStmt stmt) {
    // TODO: implement visitIfStmt
    return null;
  }

  @override
  LiteralValue visitLiteralExpr(LiteralExpr expr) {
    return new LiteralValue(expr.type, expr.value);
  }

  @override
  visitLogicalExpr(LogicalExpr expr) {
    // TODO: implement visitLogicalExpr
    return null;
  }

  @override
  visitPrintStmt(PrintStmt stmt) {
    // TODO: implement visitPrintStmt
    return null;
  }

  @override
  visitReturnStmt(ReturnStmt stmt) {
    // TODO: implement visitReturnStmt
    return null;
  }

  @override
  visitUnaryExpr(UnaryExpr expr) {
    // TODO: implement visitUnaryExpr
    return null;
  }

  @override
  visitVarStmt(VarStmt stmt) {
    
  }

  @override
  visitVariableExpr(VariableExpr expr) {
    // TODO: implement visitVariableExpr
    return null;
  }

  @override
  visitWhileStmt(WhileStmt stmt) {
    // TODO: implement visitWhileStmt
    return null;
  }
  
}