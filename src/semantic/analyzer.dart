import '../ast/expression.dart';
import '../ast/statement.dart';
import '../error/error.dart';
import '../error/error_reporter.dart';
import '../symbol/scope.dart';
import '../symbol/symbol.dart';
import '../types/type.dart';
import 'scope_owner.dart';

class Analyzer implements StmtVisitor, ExprVisitor {
  ScopeOwner scopes;
  TypeTable types;
  ScopeType currentScope =  ScopeType.GLOBAL;

  Analyzer(SymbolTable table) {
    scopes = new ScopeOwner(table);
    types = table.types;

    /*for (int i = 0; i < table.scopes.length; i++) {
      print( "$i -> ${table.scopes[i]} -> ${table.scopes[i].enclosing}");
    }*/
  }

  void check(List<Stmt> ast) {
    for (Stmt node in ast) {
      resolve(node);
    }
  }

  Type resolveType(Expr expr) {
    return expr.accept(this);
  }

  void resolve(Stmt stmt) {
    stmt.accept(this);
  }

  void enterScope() {
    scopes.beginScope();
  }

  void exitScope() {
    scopes.endScope();
  }

  void checkCompatible(Type expected, Type current, int line) {
    if (!expected.isCompatible(current)) {
      ErrorReporter.report(new TypeError(line, "Expected expression of type '$expected', Got '$current'."));
    }
  }

  void checkAssignment(Type target, Type value, line) {
    if (!target.isCompatible(value)) {
        ErrorReporter.report(new TypeError(line, "Cannot assign expression of type '${value}' to variable of type '${target}'."));
      }
  }

  void checkExistence(Type type, int line) {
    if (!types.hasType(type)) {
      while (type is ArrayType) {
        type = (type as ArrayType).base;
      }

      ErrorReporter.report(new TypeError(line, "No declaration for class '$type' found"));
    }
  }

  @override
  visitAssignExpr(AssignExpr expr) {
    if (expr.target is VariableExpr) {
      Symbol target = scopes.getSymbol((expr.target as VariableExpr).name.lexeme);
      checkAssignment(target.type, resolveType(expr.value), expr.op.line);
    } else if (expr.target is IndexExpr) {
      IndexExpr target = expr.target as IndexExpr;
      checkAssignment((resolveType(target.owner) as ArrayType).base, resolveType(expr.value), expr.op.line);
    } else if (expr.target is AccessExpr) {
      AccessExpr target = expr.target as AccessExpr;
      checkAssignment(resolveType(target), resolveType(expr.value), expr.op.line);
    }
  }

  bool _isNum(Type type) {
    return type.name == BuiltinType.INT.name || type.name == BuiltinType.DOUBLE.name;
  }

  Type checkBinary(BinaryExpr expr) {
    Type left = resolveType(expr.left);
    Type right = resolveType(expr.right);
    
    if (left is! BuiltinType || right is! BuiltinType) {
      ErrorReporter.report(new TypeError(expr.op.line, "Incompatible operands: $left ${expr.op.lexeme} $right."));
      return BuiltinType.ERROR;
    }

    Type ret = left;
    if (!_isNum(left) || !_isNum(right) || !left.isCompatible(right)) {
      ErrorReporter.report(new TypeError(expr.op.line, "Incompatible operands: $left ${expr.op.lexeme} $right."));
      ret = BuiltinType.ERROR;
    }

    return ret ;
  }

  @override
  visitBinaryExpr(BinaryExpr expr) {
    switch (expr.op.lexeme) {
      case '+':
      case '-':
      case '*':
      case '/':
      case '%': 
        return expr.type = checkBinary(expr);
      case '<':
      case '<=':
      case '>':
      case '>=':
        Type type = checkBinary(expr);
        expr.type = type != null ?  BuiltinType.BOOL : type;
        return expr.type;
      case '==':
      case '!=':
        Type left = resolveType(expr.left);
        Type right = resolveType(expr.left);
        if (!left.isCompatible(right)) {
          ErrorReporter.report(new TypeError(expr.op.line, "Operands to '${expr.op.lexeme}' must be of same type. Got('$left' and '$right')."));
          return expr.type = BuiltinType.ERROR;
        }

        return expr.type = BuiltinType.BOOL;
      default:
    }
  }

  @override
  visitBlockStmt(BlockStmt stmt) {
    enterScope();
    for (Stmt stmt in stmt.statements) {
      resolve(stmt);
    }
    exitScope();
  }

  @override
  visitBreakStmt(BreakStmt stmt) {
    return null;
  }

  @override
  visitCallExpr(CallExpr expr) {
    Type type;
    String name = '';
    String kind = 'Function';
    
    if (expr.callee is VariableExpr) {
      VariableExpr callee = expr.callee as VariableExpr;
      Symbol sym = scopes.getSymbol(callee.name.lexeme);
      type = sym.type;
      name = callee.name.lexeme;
    } else if (expr.callee is AccessExpr) {
      kind = 'Method';
      name = ((expr.callee as AccessExpr).field as VariableExpr).name.lexeme;
      type = resolveType(expr.callee);
    } else {
      type = resolveType(expr.callee);
      ErrorReporter.report(new TypeError(expr.paren.line, "'$type' is not callable."));
      return BuiltinType.ERROR;
    }

    if (type is! FunctionType) {
      ErrorReporter.report(new TypeError(expr.paren.line, "No declaration for ${kind.toLowerCase()} '$name' found."));
      return BuiltinType.ERROR;
    }

    FunctionType func = type as FunctionType;

    if (expr.arguments.length != func.paramsType.length) {
      ErrorReporter.report(new TypeError(expr.paren.line, "${kind} ’$name’ expects ${func.paramsType.length} arguments but ${expr.arguments.length} given."));
      return expr.type = func.returnType;
    }

    int line = expr.paren.line;
    for (int i = 0; i < func.paramsType.length; i++) {
      Type param = resolveType(expr.arguments[i]);
      if(!func.paramsType[i].isCompatible(param)) {
        ErrorReporter.report(new TypeError(line, "Incompatible argument ${i + 1}: $param given, ${func.paramsType[i]} expected."));
      }
    }

    return expr.type = func.returnType;
  }

  @override
  visitExpressionStmt(ExpressionStmt stmt) {
    resolveType(stmt.expression);
  }

  @override
  visitForStmt(ForStmt stmt) {
    if (stmt.initializer != null) resolveType(stmt.initializer);
    checkCompatible(BuiltinType.BOOL, resolveType(stmt.condition), stmt.keyword.line);
    if (stmt.incrementer != null) resolveType(stmt.incrementer);

    resolve(stmt.body);
  }

  @override
  visitFunctionStmt(FunctionStmt stmt) {
    checkExistence(stmt.returnType, stmt.name.line);

    Symbol symbol = scopes.fromCurrent(stmt.name.lexeme);

    enterScope();

    List<Type> params = [];
    for (VarStmt param in stmt.params) {
      resolve(param);
      params.add(param.type);
    }

    (symbol.type as FunctionType).paramsType = params;

    resolve(stmt.body);
    exitScope();
  }

  @override
  visitGroupingExpr(GroupingExpr expr) {
    return expr.type = resolveType(expr.expression);
  }

  @override
  visitIfStmt(IfStmt stmt) {
    if (!BuiltinType.BOOL.isCompatible(resolveType(stmt.condition))) {
      ErrorReporter.report(new TypeError(stmt.keyword.line, "Conditional expression of 'if' must be of type bool."));
    }

    resolve(stmt.thenStmt);
    if (stmt.elseStmt != null) resolve(stmt.elseStmt);
  }

  @override
  visitLiteralExpr(LiteralExpr expr) {
    return expr.type;
  }

  @override
  visitLogicalExpr(LogicalExpr expr) {
    int line = expr.op.line;
    
    if (!BuiltinType.BOOL.isCompatible(resolveType(expr.left))) {
      ErrorReporter.report(new TypeError(line, "Left operand to '${expr.op.lexeme}' must be of type bool."));
    }
    
    if (!BuiltinType.BOOL.isCompatible(resolveType(expr.right))) {
      ErrorReporter.report(new TypeError(line, "Right operand to '${expr.op.lexeme}' must be of type bool."));
    }

    return expr.type = BuiltinType.BOOL;
  }

  @override
  visitPrintStmt(PrintStmt stmt) {
    List<String> allowed = [BuiltinType.STRING.name, BuiltinType.INT.name, BuiltinType.BOOL.name];

    for (int i = 0; i < stmt.expressions.length; i++) {
      Type type = resolveType(stmt.expressions[i]);
      if (!allowed.contains(type.name)) {
        ErrorReporter.report(new TypeError(stmt.keyword.line, "Incompatible argument ${i + 1}: $type given, int/bool/string expected."));
      }
    }
  }

  @override
  visitReturnStmt(ReturnStmt stmt) {
    Type returnType = stmt.value != null ? resolveType(stmt.value) : BuiltinType.VOID;

    if (BuiltinType.VOID.isCompatible(stmt.expectedType) && returnType.name != BuiltinType.VOID.name) {
      ErrorReporter.report(new TypeError(stmt.keyword.line, "Incompatible return: $returnType given, void expected."));
      return;
    }
    
    if (!stmt.expectedType.isCompatible(returnType)) {
      ErrorReporter.report(new TypeError(stmt.keyword.line, "Incompatible return: $returnType given, ${stmt.expectedType} expected."));
      return;
    }
  }

  @override
  visitUnaryExpr(UnaryExpr expr) {
    Type type = resolveType(expr.expression);
    if (expr.op.lexeme == '!') {
      if (!BuiltinType.BOOL.isCompatible(type)) {
        ErrorReporter.report(new TypeError(expr.op.line, "Incompatible operand: ! $type."));
      }
      
      return expr.type = BuiltinType.BOOL;
    } else {
      String name = (type as BuiltinType).name;
      if (name != BuiltinType.INT.name && name != BuiltinType.DOUBLE.name) {
        ErrorReporter.report(new TypeError(expr.op.line, "Operands to unary '-' must be either of type 'int'or 'double'."));
      }

      return expr.type = type;
    }
  }

  @override
  visitVarStmt(VarStmt stmt) {
    Symbol symbol = scopes.fromCurrent(stmt.name.lexeme);

    checkExistence(symbol.type, stmt.name.line);

    if (stmt.initializer != null) {
      Type type = resolveType(stmt.initializer);
      checkAssignment(symbol.type, type, stmt.name.line);
    }
  }

  @override
  visitVariableExpr(VariableExpr expr) {
    return scopes.getSymbol(expr.name.lexeme).type;
  }

  @override
  visitWhileStmt(WhileStmt stmt) {
    checkCompatible(BuiltinType.BOOL, resolveType(stmt.condition), stmt.keyword.line);
    resolve(stmt.body);
  }

  @override
  visitArrayExpr(ArrayExpr expr) {
    Type type = resolveType(expr.size);
    if (!BuiltinType.INT.isCompatible(type)) {
      ErrorReporter.report(new TypeError(expr.keyword.line, "Size for array must be an integer."));
    }

    return expr.type = new ArrayType(expr.type);
  }

  @override
  visitIndexExpr(IndexExpr expr) {
    Type type = resolveType(expr.owner);
    if (type is! ArrayType) {
      ErrorReporter.report(new TypeError(expr.bracket.line, "[] can only be applied to arrays."));
      type = BuiltinType.ERROR;
    }

    if (!BuiltinType.INT.isCompatible(resolveType(expr.index))) {
      ErrorReporter.report(new TypeError(expr.bracket.line, "Array subscript must be an integer."));
      type = BuiltinType.ERROR;
    }

    return type.name == BuiltinType.ERROR.name ? type : (type as ArrayType).base;
  }

  @override
  visitClassStmt(ClassStmt stmt) {
    enterScope();
    currentScope = ScopeType.CLASS;

    for (VarStmt field in stmt.fields) {
      resolve(field);
    }

    for (FunctionStmt method in stmt.methods) {
      resolve(method);
    }

    exitScope();
    currentScope = ScopeType.GLOBAL;
  }

  @override
  visitAccessExpr(AccessExpr expr) {
    Type type = resolveType(expr.target);
    if (type is! CustomType) {
      ErrorReporter.report(new TypeError(expr.dot.line, "$type has no such field '${(expr.field as VariableExpr).name.lexeme}'."));
      return;
    }

    CustomType target = types.getType(type);
    String field = (expr.field as VariableExpr).name.lexeme;

    // Check wether the class has the field
    if (target.scope.has(field)) {
      type = target.scope.getSymbol(field).type;
      if (type is! FunctionType && currentScope != ScopeType.CLASS) {
        ErrorReporter.report(new SemanticError(expr.dot, "$target field '$field' only accessible within class scope."));
        return BuiltinType.NULL;
      }

      return type;
    } else {
      ErrorReporter.report(new TypeError(expr.dot.line, "$target has no such field '$field'."));
      return BuiltinType.NULL;
    }
  }

  @override
  visitThisExpr(ThisExpr expr) {
    return expr.type;
  }
}