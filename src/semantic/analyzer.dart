import '../ast/expression.dart';
import '../ast/statement.dart';
import '../error/error.dart';
import '../error/error_reporter.dart';
import '../lexer/tokens.dart';
import '../symbol/scope.dart';
import '../symbol/symbol.dart';
import '../types/type.dart';
import 'scope_owner.dart';

class Analyzer implements StmtVisitor, ExprVisitor {
  ScopeOwner scopes;
  TypeTable types;
  ScopeType currentScope =  ScopeType.GLOBAL;
  Symbol currentClass;

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

  void checkAssignment(Type target, Type value, int line) {
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
      Type type = resolveType(target.owner);
      if (type is ArrayType) {
        checkAssignment(type.base, resolveType(expr.value), expr.op.line);
      } else {
        ErrorReporter.report(new TypeError(expr.op.line, "'${target.owner}' is not of type array."));
      }
      
    } else if (expr.target is AccessExpr) {
      AccessExpr target = expr.target as AccessExpr;
      checkAssignment(resolveType(target), resolveType(expr.value), expr.op.line);
    }
  }

  bool _isNum(Type type) {
    List<String> types = [BuiltinType.INT.name, BuiltinType.DOUBLE.name, BuiltinType.ERROR.name];
    return types.contains(type.name);
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
        Type right = resolveType(expr.right);
        if (!left.isCompatible(right) && !right.isCompatible(left)) {
          ErrorReporter.report(new TypeError(expr.op.line, "Operands to '${expr.op.lexeme}' must be of compatible type. Got('$left' and '$right')."));
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

    if (type is ArrayType && name == 'length') {
      return expr.type = BuiltinType.INT;
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
        ErrorReporter.report(new TypeError(line, "Incompatible argument ${i + 1} to ${kind.toLowerCase()} '$name': $param given, ${func.paramsType[i]} expected."));
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
    expr.type = resolveType(expr.expression);
    return expr.type;
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
    List<String> allowed = [BuiltinType.STRING.name, BuiltinType.INT.name, BuiltinType.BOOL.name, BuiltinType.ERROR.name];

    for (int i = 0; i < stmt.expressions.length; i++) {
      Type type = resolveType(stmt.expressions[i]);
      if (!allowed.contains(type.name)) {
        ErrorReporter.report(new TypeError(stmt.keyword.line, "Incompatible argument ${i + 1} to 'print': $type given, int/bool/string expected."));
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
    String name = expr.name.lexeme;
    if (types.hasNamedType(name)) {
      ErrorReporter.report(new TypeError(expr.name.line, "No declaration found for variable '$name'."));
      return BuiltinType.ERROR;
    }
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
    currentClass = scopes.getAt(0, stmt.name.lexeme);

    for (VarStmt field in stmt.fields) {
      resolve(field);
    }

    Map<Token, Symbol> syms = {};
    for (FunctionStmt method in stmt.methods) {
      resolve(method);
      syms[method.name] = scopes.current.getSymbol(method.name.lexeme);
    }

    if (stmt.parent != null) {
      _checkOverrides(syms, types.getNamedType(stmt.parent.lexeme));
    }

    exitScope();
    currentScope = ScopeType.GLOBAL;
    currentClass = null;
  }

  void _checkOverrides(Map<Token, Symbol> methods, NamedType parent) {
    for (Token method in methods.keys) {
      Type type = parent.scope.getClassSymbol(method.lexeme)?.type;
      if (type is FunctionType) {
        // Check override only if method is not constructor
        if (!type.isConstruct && !type.isMethodCompatible(methods[method].type)) {
          ErrorReporter.report(new TypeError(method.line, "Overriden method '${method.lexeme}' signature must be compatible with parent's class one"));
        }
      }
    }
  }

  @override
  visitAccessExpr(AccessExpr expr) {
    Type type = resolveType(expr.object);
    String field = (expr.field as VariableExpr).name.lexeme;

    if (type is ArrayType && field == 'length') {
      return type;
    }

    if (expr.object is VariableExpr) {
      if (types.hasNamedType((expr.object as VariableExpr).name.lexeme)) {
        ErrorReporter.report(new TypeError(expr.dot.line, "Cannot get field '$field' on type $type."));
        return;
      }
    }

    if (type is! NamedType) {
      ErrorReporter.report(new TypeError(expr.dot.line, "$type has no such field '$field'."));
      return;
    }

    NamedType target = types.getType(type);

    // Check wether the class has the field
    if (target.scope.classHas(field)) {
      type = target.scope.getClassSymbol(field).type;
      if (type is! FunctionType) {
        if (currentScope != ScopeType.CLASS) {
          ErrorReporter.report(new SemanticError(expr.dot, "$target field '$field' only accessible within class scope."));
        } else if (currentClass != null && !target.isCompatible(currentClass.type)) {
          // If we're in a class context and try to access unrelated class field, throw an error
          ErrorReporter.report(new SemanticError(expr.dot, "$target field '$field' cannot be accessed within unrelated class scope."));
        }
      }

      return type;
    } else {
      ErrorReporter.report(new TypeError(expr.dot.line, "$target has no such field '$field'."));
      return BuiltinType.ERROR;
    }
  }

  @override
  visitThisExpr(ThisExpr expr) {
    return expr.type;
  }

  @override
  visitNewExpr(NewExpr expr) {
    if (!types.hasType(expr.type)) {
      ErrorReporter.report(new TypeError(expr.keyword.line, "No declaration for class ’${expr.type}’ found."));
      expr.type = BuiltinType.NULL;
      return;
    }

    NamedType type = types.getNamedType(expr.type.name) as NamedType;
    expr.type = type;

    if (type.scope.classHas('construct')) {
      Symbol init = type.scope.getClassSymbol('construct');
      if (init.type is FunctionType) {
        FunctionType func = init.type; 
        // If there is a constructor check its signature
        if (func.paramsType.length != expr.args.length) {
          ErrorReporter.report(new TypeError(expr.keyword.line, '$type constructor expects ${func.paramsType.length} arguments but ${expr.args.length} given.'));
          return expr.type;
        }

        int line = expr.keyword.line;
        for (int i = 0; i < func.paramsType.length; i++) {
          Type param = resolveType(expr.args[i]);
          if(!func.paramsType[i].isCompatible(param)) {
            ErrorReporter.report(new TypeError(line, "Incompatible argument ${i + 1} to $type constructor: $param given, ${func.paramsType[i]} expected."));
          }
        }
      }
    } else {
      // If the class doesn't have a constructor disallow passing arguments to the new expression
      if (expr.args.length != 0) {
        ErrorReporter.report(new TypeError(expr.keyword.line, '$type constructor expects 0 arguments but ${expr.args.length} given.'));
      }
    }

    return expr.type;
  }

  @override
  visitReadExpr(ReadExpr expr) {
    return expr.type;
  }
}