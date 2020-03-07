import '../ast/expression.dart';
import '../ast/statement.dart';
import '../error/error.dart';
import '../error/error_reporter.dart';
import '../lexer/tokens.dart';
import '../symbol/scope.dart';
import '../symbol/symbol.dart';
import '../types/type.dart';

enum ScopeKind {
  GLOBAL,
  FUNCTION,
}

enum LoopScope {
  NONE,
  LOOP
}

class Resolver implements StmtVisitor, ExprVisitor {
  SymbolTable symbols;
  ScopeKind scope = ScopeKind.GLOBAL;
  FunctionStmt currentFunc;
  LoopScope loop = LoopScope.NONE;
  List<int> scopes = [];

  Resolver(this.symbols) {
    
  }
  
  SymbolTable resolve(List<Stmt> ast) {
    symbols.beginScope(ScopeType.GLOBAL);

    for (Stmt stmt in ast) {
      declare(stmt);
    }

    for (Stmt stmt in ast) {
      _resolve(stmt);
    }
    
    symbols.endScope();

    return symbols;
  }

  void declare(Stmt stmt) {
    Token name;
    
    name = (stmt as DeclStmt).name;

    if (symbols.inScope(name.lexeme)) {
      ErrorReporter.report(new SemanticError(name, "Name '${name.lexeme}' has already been declared in this scope."));
    }
    
    symbols.addSymbol(new Symbol(name.lexeme));
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
    symbols.beginScope(ScopeType.BLOCK);
    for (Stmt stmt in block.statements) {
      _resolve(stmt);
    }
    symbols.endScope();
  }

  @override
  visitBreakStmt(BreakStmt stmt) {
    if (loop != LoopScope.LOOP) {
      ErrorReporter.report(new SemanticError(stmt.keyword, "break is only allowed inside a loop."));
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

    // Declare function
    Symbol symbol = new Symbol(name);
    symbol.type = new FunctionType(stmt.returnType, stmt.params.map((VarStmt v) => v.type).toList());
    symbols.setSymbol(name, symbol);

    ScopeKind enclosing = scope;
    scope = ScopeKind.FUNCTION;
    currentFunc = stmt;

    symbols.beginScope(ScopeType.FORMALS);
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
    if (scope != ScopeKind.FUNCTION) {
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

      symbol.type = stmt.type;
      symbols.setSymbol(name, symbol);
  }

  @override
  visitVariableExpr(VariableExpr expr) {
    if (!symbols.hasSymbol(expr.name.lexeme)) {
      ErrorReporter.report(new SemanticError(expr.name, "No declaration for function '${expr.name.lexeme}' found."));
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

  @override
  visitArrayExpr(ArrayExpr expr) {
    _resolve(expr.size);
  }

  @override
  visitIndexExpr(IndexExpr expr) {
    _resolve(expr.owner);
    _resolve(expr.index);
  }

  @override
  visitClassStmt(ClassStmt stmt) {
    String name = stmt.name.lexeme;
    Symbol symbol = new Symbol(name, new CustomType(name));
    symbols.setSymbol(name, symbol);

    symbols.beginScope(ScopeType.CLASS);
    // Declare all fields in current scope
    for (VarStmt field in stmt.fields) {
      declare(field);
    }

    // Then declare all methods
    for (FunctionStmt method in stmt.methods) {
      declare(method);
    }

    // Now resolve fields
    for (VarStmt field in stmt.fields) {
      _resolve(field);
    }

    for (FunctionStmt method in stmt.methods) {
      _resolve(method);
    }

    symbols.endScope();
  }

}