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
  Symbol currentClass = null;

  Resolver(this.symbols);
  
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
      ErrorReporter.report(new SemanticError(name, "Declaration of '${name.lexeme}' here conflicts with previous declaration."));
    }
    
    symbols.addSymbol(new Symbol(name.lexeme));
    if (stmt is ClassStmt) {
      symbols.registerType(new NamedType(stmt.name.lexeme));
    }
  }

  void _resolve(dynamic node) {
    node.accept(this);
  }

  @override
  visitAssignExpr(AssignExpr expr) {
    _resolve(expr.target);
    _resolve(expr.value);

    if (expr.target is VariableExpr) {
      String target = (expr.target as VariableExpr).name.lexeme;
      symbols.getSymbol(target)?.initialized = true;
    }
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
    if (stmt.incrementer !=  null) _resolve(stmt.incrementer);
    
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
    symbol.type = new FunctionType(stmt.returnType, stmt.params.map((VarStmt v) => v.type).toList(), stmt.isConstruct);
    symbols.setSymbol(name, symbol);

    ScopeKind enclosing = scope;
    scope = ScopeKind.FUNCTION;
    currentFunc = stmt;

    symbols.beginScope(ScopeType.FORMALS);
    for (VarStmt param in stmt.params) {
      declare(param);
    }
    
    for (VarStmt param in stmt.params) {
      _resolve(param);
      // Mark function parameters as initialized
      if (symbols.hasSymbol(param.name.lexeme)) {
        symbols.current.getSymbol(param.name.lexeme).initialized = true;
      } 
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

    if (symbols.typeExists(name)) {
      ErrorReporter.report(new SemanticError(stmt.name, "Cannot use class name $name as object instance name."));
    }

    Symbol symbol = new Symbol(name);
    if (stmt.initializer != null) {
      _resolve(stmt.initializer);
      symbol.initialized = true;
    }

    if (stmt.type is NamedType) {
      NamedType type = symbols.getType(stmt.type.name);
      if (type == null) {
        ErrorReporter.report(new TypeError(stmt.name.line, "Type '${stmt.type.name}' does not exist."));
      }
      symbol.type = type;
    } else {
      symbol.type = stmt.type;
    }

    symbols.setSymbol(name, symbol);
  }

  @override
  visitVariableExpr(VariableExpr expr) {
    if (!symbols.hasSymbol(expr.name.lexeme)) {
      ErrorReporter.report(new SemanticError(expr.name, "No declaration for '${expr.name.lexeme}' found."));
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
    
    if (expr.owner is VariableExpr) {
      String owner = (expr.owner as VariableExpr).name.lexeme;
      if (!symbols.getSymbol(owner).initialized) {
        ErrorReporter.report(new SemanticError(expr.bracket, "Cannot subscript unitialized array."));
      }
    }
  }

  @override
  visitClassStmt(ClassStmt stmt) {
    String name = stmt.name.lexeme;
    NamedType type = symbols.getType(name);
    Symbol symbol = new Symbol(name, type);
    
    currentClass = symbol;
    symbols.setSymbol(name, symbol);
    Scope parent;

    // Check parent class
    if (stmt.parent != null) {
      if (stmt.parent.lexeme == stmt.name.lexeme) {
        ErrorReporter.report(new SemanticError(stmt.parent, "Cannot extends self class '${stmt.parent.lexeme}'."));
      } else {
        if (!symbols.typeExists(stmt.parent.lexeme)) {
          ErrorReporter.report(new SemanticError(stmt.parent, "No declaration for class '${stmt.parent.lexeme}' found."));
        } else {
          NamedType enclosing = symbols.getType(stmt.parent.lexeme);
          type.parent = enclosing;
          parent = enclosing.scope;
        }
      }
    }

    symbols.beginScope(ScopeType.CLASS);
    // Declare all fields in current scope
    bool hasParent = parent != null; 

    for (VarStmt field in stmt.fields) {
      if (hasParent) {
        // Check propoerty override accross all super classes
        if (parent.classHas(field.name.lexeme)) {
          ErrorReporter.report(new SemanticError(stmt.parent, "Cannot override inherited property '${field.name.lexeme}' in class '$name'."));
        }
      }

      _resolve(field);
    }

    // Then declare all methods
    for (FunctionStmt method in stmt.methods) {
      declare(method);
    }

    for (FunctionStmt method in stmt.methods) {
      _resolve(method);
    }

    type.scope = symbols.current;
    type.scope.enclosing = parent ?? symbols.scopes[0];
    symbols.updateType(type);

    symbols.endScope();

    currentClass = null;
  }

  @override
  visitAccessExpr(AccessExpr expr) {
    _resolve(expr.object);
    
    // Disallow direct constructor call
    String field = (expr.field as VariableExpr).name.lexeme;
    if (field == 'construct') {
      ErrorReporter.report(new SemanticError(expr.dot, "Cannot directly call class constructor."));
      return;
    }
    
    if (expr.object is VariableExpr) {
      String owner = (expr.object as VariableExpr).name.lexeme;

      Symbol sym = symbols.getSymbol(owner);
      var init = sym?.initialized;

      if (init == null || !init) {
        ErrorReporter.report(new SemanticError(expr.dot, "Cannot access '$field' on unitialized object."));
      }
    }
  }

  @override
  visitThisExpr(ThisExpr expr) {
    if (currentClass == null) {
      ErrorReporter.report(new SemanticError(expr.keyword, "’this’ is only valid within class scope."));
      expr.type = BuiltinType.NULL;
      return;
    }
    
    expr.type = currentClass.type;
  }

  @override
  visitNewExpr(NewExpr expr) {
    if (expr.type is! NamedType) {
      ErrorReporter.report(new TypeError(expr.keyword.line, "’${expr.type}’ is not a class."));
      expr.type = BuiltinType.NULL;
      return;
    }

    for (Expr arg in expr.args) {
      _resolve(arg);
    }
  }

  @override
  visitReadExpr(ReadExpr expr) {
    return null;
  }

}