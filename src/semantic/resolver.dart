import '../ast/expression.dart';
import '../ast/statement.dart';
import '../error/error.dart';
import '../error/error_reporter.dart';
import '../symbol/symbol.dart';

enum Scope {
  GLOBAL,
  FUNCTION,
}

enum LoopScope {
  NONE,
  LOOP
}

class Resolver implements StmtVisitor, ExprVisitor {
  SymbolTable symbols;
  Scope scope = Scope.GLOBAL;
  FunctionStmt currentFunc;
  LoopScope loop = LoopScope.NONE;
  List<int> scopes = [];

  Resolver(this.symbols) {
    
  }
  
  SymbolTable resolve(List<Stmt> ast) {
    symbols.beginScope();
    for (Stmt stmt in ast) {
      _resolve(stmt);
    }
    symbols.endScope();

    return symbols;
  }

  void _resolve(dynamic node) {
    node.accept(this);
  }

  @override
  visitAssignExpr(AssignExpr expr) {
    _resolve(expr.target);
    _resolve(expr.value);
  }

  @override
  visitBinaryExpr(BinaryExpr expr) {
    _resolve(expr.left);
    _resolve(expr.right);
  }

  @override
  visitBlockStmt(BlockStmt block) {
    symbols.beginScope();
    for (Stmt stmt in block.statements) {
      _resolve(stmt);
    }
    symbols.endScope();
  }

  @override
  visitBreakStmt(BreakStmt stmt) {
    if (loop != LoopScope.LOOP) {
      ErrorReporter.report(new SemanticError(stmt.keyword, "Cannot use 'break' outside from a loop scope."));
    }
  }

  @override
  visitCallExpr(CallExpr expr) {
    _resolve(expr.callee);
    for (Expr arg in expr.arguments) {
      _resolve(arg);
    }
  }

  @override
  visitExpressionStmt(ExpressionStmt stmt) {
    _resolve(stmt.expression);
  }

  @override
  visitForStmt(ForStmt stmt) {
    if (stmt.initializer !=  null) _resolve(stmt.initializer);
    _resolve(stmt.condition);
    
    LoopScope enclosing = loop;
    loop = LoopScope.LOOP;
    
    _resolve(stmt.body);

    loop = enclosing;
  }

  @override
  visitFunctionStmt(FunctionStmt stmt) {
    String name = stmt.name.lexeme;

    if (symbols.inScope(name)) {
      ErrorReporter.report(new SemanticError(stmt.name, "Name '$name' has already been declared in this scope."));
    }

    // Declare function
    Symbol symbol = new Symbol(name);
    symbols.addSymbol(symbol);

    Scope enclosing = scope;
    scope = Scope.FUNCTION;
    currentFunc = stmt;

    symbols.beginScope();
    for (VarStmt param in stmt.params) {
      _resolve(param);
    }
    
    _resolve(stmt.body);

    symbols.endScope();

    scope = enclosing;
    currentFunc = null;
  }

  @override
  visitGroupingExpr(GroupingExpr expr) {
    _resolve(expr.expression);
  }

  @override
  visitIfStmt(IfStmt stmt) {
    _resolve(stmt.condition);
    _resolve(stmt.thenStmt);

    if (stmt.elseStmt != null) _resolve(stmt.elseStmt);
  }

  @override
  visitLiteralExpr(LiteralExpr expr) {
    return null;
  }

  @override
  visitLogicalExpr(LogicalExpr expr) {
    _resolve(expr.left);
    _resolve(expr.right);
  }

  @override
  visitPrintStmt(PrintStmt stmt) {
    for (Expr expr in stmt.expressions) {
      _resolve(expr);
    }
  }

  @override
  visitReturnStmt(ReturnStmt stmt) {
    if (scope != Scope.FUNCTION) {
      ErrorReporter.report(new SemanticError(stmt.keyword, "Cannot return from a non-function scope."));
    } else {
      stmt.expectedType = currentFunc.returnType;
    }
    
    if (stmt.value != null) {
      _resolve(stmt.value);
    }
  }

  @override
  visitUnaryExpr(UnaryExpr expr) {
    _resolve(expr.expression);
  }

  @override
  visitVarStmt(VarStmt stmt) {
    String name = stmt.name.lexeme;

    Symbol symbol = new Symbol(name);
    if (stmt.initializer != null) {
      _resolve(stmt.initializer);
    }

    if (symbols.inScope(name)) {
      ErrorReporter.report(new SemanticError(stmt.name, "Name '$name' has already been declared in this scope."));
    } else {
      symbols.addSymbol(symbol);
    }
  }

  @override
  visitVariableExpr(VariableExpr expr) {
    if (!symbols.hasSymbol(expr.name.lexeme)) {
      ErrorReporter.report(new SemanticError(expr.name, "Variable '${expr.name.lexeme}' has never been declared."));
    }
  }

  @override
  visitWhileStmt(WhileStmt stmt) {
    _resolve(stmt.condition);
    LoopScope enclosing = loop;
    loop = LoopScope.LOOP;
    
    _resolve(stmt.body);

    loop = enclosing;
  }

}