import '../ast/expression.dart';
import '../ast/statement.dart';
import '../error/error.dart';
import '../error/error_reporter.dart';
import '../symbol/symbol.dart';
import '../types/type.dart';

class Analyzer implements StmtVisitor, ExprVisitor {
  SymbolTable symbols;
  int scope = 0;

  Analyzer(this.symbols) {
    for (int i = 0; i < this.symbols.scopes.length; i++) {
      print( "$i -> ${symbols.scopes[i].symbols.keys} -> ${symbols.scopes[i].enclosing?.symbols?.keys}");
    }
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
    //print(symbols.scopes[scope].symbols.keys.toString() + ' -> ' + scope.toString());
    scope++;
  }

  void exitScope() {
    scope--;
  }

  void checkCompatible(Type expected, Type current, int line) {
    if (!expected.check(current)) {
      ErrorReporter.report(new TypeError(line, "Expected expression of type '$expected', Got '$current'."));
    }
  }

  void checkAssignment(Type target, Type value, line) {
    if (!target.check(value)) {
        ErrorReporter.report(new TypeError(line, "Cannot assign expression of type '${value}' to variable of type '${target}'."));
      }
  }

  @override
  visitAssignExpr(AssignExpr expr) {
    Symbol target = symbols.getFrom(scope, (expr.target as VariableExpr).name.lexeme);
    checkAssignment(target.type, resolveType(expr.value), expr.op.line);
  }

  Type checkBinary(BinaryExpr expr) {
    BuiltinType left = resolveType(expr.left) as BuiltinType;
    BuiltinType right = resolveType(expr.right) as BuiltinType;
    Type ret;
    if (left.name != BuiltinType.INT.name && left.name != BuiltinType.DOUBLE.name) {
      ErrorReporter.report(new TypeError(expr.op.line, "Left operand to '${expr.op.lexeme}' must be either of type int or double."));
      ret = BuiltinType.ERROR;
    }

    if (right.name != BuiltinType.INT.name && right.name != BuiltinType.DOUBLE.name) {
      ErrorReporter.report(new TypeError(expr.op.line, "Right operand to '${expr.op.lexeme}' must be either of type int or double."));
      ret = BuiltinType.ERROR;
    }

    if (left.name != right.name) {
      ErrorReporter.report(new TypeError(expr.op.line, "Operands to '${expr.op.lexeme}' must be both of type either int or double."));
      ret = BuiltinType.ERROR;
    }

    return ret ?? left;
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
        if (!left.check(right)) {
          ErrorReporter.report(new TypeError(expr.op.line, "Operands to '${expr.op.lexeme}' must be of same type. Got('$left' and '$right')."));
          return expr.type = BuiltinType.ERROR;
        }

        return expr.type = BuiltinType.BOOL;
      default:
    }
  }

  @override
  visitBlockStmt(BlockStmt stmt) {
    enterScope();print('In block -> $scope');
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
    VariableExpr callee = expr.callee as VariableExpr;
    Symbol sym = symbols.getFrom(scope, callee.name.lexeme);
    if (sym.type is! FunctionType) {
      ErrorReporter.report(new TypeError(expr.paren.line, "Identifier '${callee.name.lexeme}' is not a function."));
      return BuiltinType.ERROR;
    }

    FunctionType func = sym.type as FunctionType;

    if (expr.arguments.length != func.paramsType.length) {
      ErrorReporter.report(new TypeError(expr.paren.line, "Invalid arguments number to function '${callee.name.lexeme}'. Expected ${func.paramsType.length} but got ${expr.arguments.length}."));
      return BuiltinType.ERROR;
    }

    int line = expr.paren.line;
    for (int i = 0; i < func.paramsType.length; i++) {
      Type param = resolveType(expr.arguments[i]);
      if(!func.paramsType[i].check(param)) {
        ErrorReporter.report(new TypeError(line, "Argument ${i + 1} to function '${callee.name.lexeme}' must be of type '${func.paramsType[i]}'. Provided '$param'."));
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
    Symbol symbol = symbols.getFrom(scope, stmt.name.lexeme);

    enterScope();print('In function -> $scope');

    List<Type> params = [];
    for (VarStmt param in stmt.params) {
      resolve(param);
      params.add(param.type);
    }

    symbol.type = new FunctionType(stmt.returnType, params);

    resolve(stmt.body);
    exitScope();
  }

  @override
  visitGroupingExpr(GroupingExpr expr) {
    return expr.type = resolveType(expr.expression);
  }

  @override
  visitIfStmt(IfStmt stmt) {
    if (!BuiltinType.BOOL.check(resolveType(stmt.condition))) {
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
    
    if (!BuiltinType.BOOL.check(resolveType(expr.left))) {
      ErrorReporter.report(new TypeError(line, "Left operand to '${expr.op.lexeme}' must be of type bool."));
    }
    
    if (!BuiltinType.BOOL.check(resolveType(expr.right))) {
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
        ErrorReporter.report(new TypeError(stmt.keyword.line, "Parameter $i to print does not have a valid type (int, bool, string)."));
      }
    }
  }

  @override
  visitReturnStmt(ReturnStmt stmt) {
    Type returnType = stmt.value != null ? resolveType(stmt.value) : BuiltinType.VOID;

    if (BuiltinType.VOID.check(stmt.expectedType) && returnType.name != BuiltinType.VOID.name) {
      ErrorReporter.report(new TypeError(stmt.keyword.line, "Cannot return a non null value from a void-return function."));
      return;
    }
    
    if (!stmt.expectedType.check(returnType)) {
      ErrorReporter.report(new TypeError(stmt.keyword.line, "Invaid return value type from function. Expected '${stmt.expectedType}', Got '$returnType'."));
      return;
    }
  }

  @override
  visitUnaryExpr(UnaryExpr expr) {
    Type type = resolveType(expr.expression);
    if (expr.op.lexeme == '!') {
      checkCompatible(BuiltinType.BOOL, type, expr.op.line);
      return expr.type = BuiltinType.BOOL;
    } else {
      String name = (type as BuiltinType).name;
      if (name != 'int' && name != 'double') {
        ErrorReporter.report(new TypeError(expr.op.line, "Operands to unary '-' must be either of type 'int'or 'double'."));
      }

      return expr.type = type;
    }
  }

  @override
  visitVarStmt(VarStmt stmt) {
    Symbol symbol = symbols.getAt(scope, stmt.name.lexeme);
    //print(stmt.name.lexeme);print(scope);
    symbol.type = stmt.type;

    if (stmt.initializer != null) {
      Type type = resolveType(stmt.initializer);
      checkAssignment(symbol.type, type, stmt.name.line);
    }
  }

  @override
  visitVariableExpr(VariableExpr expr) {
    return symbols.getFrom(scope, expr.name.lexeme).type;
  }

  @override
  visitWhileStmt(WhileStmt stmt) {
    checkCompatible(BuiltinType.BOOL, resolveType(stmt.condition), stmt.keyword.line);
    resolve(stmt.body);
  }
}