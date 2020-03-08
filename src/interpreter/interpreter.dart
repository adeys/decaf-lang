import 'dart:io';

import '../ast/expression.dart';
import '../ast/statement.dart';
import '../error/error.dart';
import '../symbol/symbol.dart';
import '../types/type.dart';
import 'environmnent.dart';
import 'value.dart';

class Break {
  
}

class Interpreter implements StmtVisitor, ExprVisitor {
  SymbolTable symbols;
  Environment _env;

  Interpreter(this.symbols) {
    _env = new Environment();
  }

  Value evaluate(List<Stmt> ast) {
    Symbol main = symbols.getAt(0, 'main');

    // Check wether a 'main' function has been declared
    if (main == null || main.type is! FunctionType) {
      throw new CompilerError("Program does not contain 'main' function.");
    }

    for (Stmt stmt in ast) {
      _execute(stmt);
    }

    // Execute the main function
    return (_env.getAt(0, 'main') as DecafFunction).callFun(this, []);
  }

  Value _execute(Stmt stmt) {
    return stmt.accept(this);
  }

  Value _evaluate(Expr expr) {
    return expr.accept(this);
  }

  @override
  visitAssignExpr(AssignExpr expr) {
    Value value = _evaluate(expr.value);
    
    if (expr.target is VariableExpr) {
      _env.assign((expr.target as VariableExpr).name, value);
    } else if (expr.target is IndexExpr) {
      IndexExpr target = expr.target as IndexExpr;
      Value result = _evaluate(target.owner);

      if (result is! ArrayValue) {
        throw new RuntimeError(target.bracket, "[] can only be applied to arrays.");
      }

      ArrayValue array = result as ArrayValue;

      int index = _evaluate(target.index).value as int;

      if (index < 0 || index >= array.size) {
        throw new RuntimeError(expr.op, "Array index out of bounds.");
      }
      
      array.set(index, value);
    }

  }

  @override
  visitBinaryExpr(BinaryExpr expr) {
    Object left = _evaluate(expr.left).value;
    Object right = _evaluate(expr.right).value;

    Object value;

    switch (expr.op.lexeme) {
      case '+': value = (left as num) + (right as num); break;
      case '-': value = (left as num) - (right as num); break;
      case '*': value = (left as num) * (right as num); break;
      case '%': {
        if ((right as num) == 0) throw new DivisionByZeroError(expr.op);
        value = ((left as num) % (right as num)).toInt(); break;
      }
      case '/': {
        if ((right as num) == 0) throw new DivisionByZeroError(expr.op);
        value = ((left as num) / (right as num)).toDouble(); break;
      }
      case '<': value = (left as num) < (right as num); break;
      case '<=': value = (left as num) <= (right as num); break;
      case '>': value = (left as num) > (right as num); break;
      case '>=': value = (left as num) >= (right as num); break;
      case '==': value = left == right; break;
      case '!=': value = left != right; break;
      default:
    }

    return new Value(expr.type, value);
  }

  executeBlock(List<Stmt> statements, Environment current) {
    Environment old = _env;
    _env = current;
    
    try {
      for (Stmt stmt in statements) {
        _execute(stmt);
      }
    } finally {
      _env = old;
    }
  }

  @override
  visitBlockStmt(BlockStmt stmt) {
    executeBlock(stmt.statements, new Environment(_env));
  }

  @override
  visitBreakStmt(BreakStmt stmt) {
    throw new Break();
  }

  @override
  visitCallExpr(CallExpr expr) {
    DecafCallable callable = _evaluate(expr.callee);

    List<Value> args = expr.arguments.map((Expr expr) => _evaluate(expr)).toList();

    return callable.callFun(this, args);
  }

  @override
  visitExpressionStmt(ExpressionStmt stmt) {
    _evaluate(stmt.expression);
  }

  @override
  visitForStmt(ForStmt stmt) {
    if (stmt.initializer != null) _evaluate(stmt.initializer);
    while (_evaluate(stmt.condition).value == true) {
      try {
        _execute(stmt.body);
        if (stmt.incrementer != null) _evaluate(stmt.incrementer);
      } on Break catch(_) {
        return;
      }
    }
  }

  @override
  visitFunctionStmt(FunctionStmt stmt) {
    _env.define(stmt.name.lexeme, new DecafFunction(stmt, _env));
  }

  @override
  visitGroupingExpr(GroupingExpr expr) {
    return _evaluate(expr.expression);
  }

  @override
  visitIfStmt(IfStmt stmt) {
    Value cond = _evaluate(stmt.condition);
    if (cond.value == true) _execute(stmt.thenStmt);
    else if (stmt.elseStmt != null) _execute(stmt.elseStmt);
  }

  @override
  Value visitLiteralExpr(LiteralExpr expr) {
    return new Value(expr.type, expr.value);
  }

  @override
  visitLogicalExpr(LogicalExpr expr) {
    Value left = _evaluate(expr.left);
    Value right = _evaluate(expr.right);
    bool result;

    result = expr.op.lexeme == '&&' 
      ? left.value == true && right.value == true
      : left.value == true || right.value == true;

    return new Value(expr.type, result);
  }

  @override
  visitPrintStmt(PrintStmt stmt) {
    StringBuffer buffer = new StringBuffer();
    for (Expr expr in stmt.expressions) {
      Value value = _evaluate(expr);
      buffer.write(value.toString());
    }

    stdout.write(buffer.toString());
  }

  @override
  visitReturnStmt(ReturnStmt stmt) {
    Value value = stmt.value != null ? _evaluate(stmt.value) : new NullValue();
    throw new Return(value);
  }

  @override
  visitUnaryExpr(UnaryExpr expr) {
    Value result = _evaluate(expr.expression);
    if (expr.op.lexeme == '!') {
      result.value = !result.value;
    } else {
      result.value = -(result.value as num);
    }

    result.type = expr.type;
    return result;
  }

  @override
  visitVarStmt(VarStmt stmt) {
    Value value = new Value(stmt.type);
    value.value = stmt.initializer != null ? _evaluate(stmt.initializer).value : null;

    _env.define(stmt.name.lexeme, value);
  }

  @override
  visitVariableExpr(VariableExpr expr) {
    return _env.get(expr.name);
  }

  @override
  visitWhileStmt(WhileStmt stmt) {
    while (_evaluate(stmt.condition).value == true) {
      try {
        _execute(stmt.body);
      } on Break catch(_) {
        return;
      }
    }
  }

  @override
  visitArrayExpr(ArrayExpr expr) {
    int size = _evaluate(expr.size).value as int;

    if (size < 0) {
      throw new RuntimeError(expr.keyword, "Array size must be >= 0.");
    }

    return new ArrayValue(expr.type, size);
  }

  @override
  visitIndexExpr(IndexExpr expr) {
    ArrayValue owner = _evaluate(expr.owner);
    int index = _evaluate(expr.index).value as int;

    if (index < 0 || index >= owner.size) {
      throw new RuntimeError(expr.bracket, "Array index out of bounds.");
    }
    
    return owner.get(index); 
  }

  @override
  visitClassStmt(ClassStmt stmt) {
    DecafClass klass = new DecafClass(stmt.name.lexeme);
    _env.define(stmt.name.lexeme, klass);

    _env = new Environment(_env);

    for (VarStmt field in stmt.fields) {
      _execute(field);
    }

    for (FunctionStmt method in stmt.methods) {
      _execute(method);
    }

    klass.scope = _env;
    
    _env = _env.parent;
    _env.assign(stmt.name, klass);
  }

  @override
  visitAccessExpr(AccessExpr expr) {
    // TODO: implement visitAccessExpr
    return null;
  }
  
}