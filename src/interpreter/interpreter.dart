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

Map<String, Object> _defaults = {
  BuiltinType.INT.name: 0,
  BuiltinType.DOUBLE.name: 0,
  BuiltinType.BOOL.name: false,
  BuiltinType.STRING.name: "",
};

class Interpreter implements StmtVisitor, ExprVisitor {
  SymbolTable symbols;
  Environment _env;
  Environment _globals = new Environment();

  Interpreter(this.symbols) {
    _env = _globals;
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
    return (_globals.getAt(0, 'main') as DecafFunction).callFun(this, []);
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
    } else if (expr.target is AccessExpr) {
      AccessExpr target = expr.target as AccessExpr;
      DecafInstance instance = _evaluate(target.object);
      VariableExpr field = target.field as VariableExpr;
      
      instance.setField(field.name, value);
    }
  }

  @override
  visitBinaryExpr(BinaryExpr expr) {
    Value leftVal = _evaluate(expr.left);
    Value rightVal = _evaluate(expr.right);

    Object left = leftVal.value;
    Object right = rightVal.value;

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
      case '==': value = leftVal.equalsTo(rightVal); break;
      case '!=': value = !leftVal.equalsTo(rightVal); break;
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
    Value callable = _evaluate(expr.callee);

    if (callable is DecafCallable) {
      List<Value> args = expr.arguments.map((Expr expr) => _evaluate(expr)).toList();

      return callable.callFun(this, args);
    } else if (callable is ArrayValue) {
      return new Value(BuiltinType.INT, callable.size);
    }
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
    _env.define(stmt.name.lexeme, new DecafFunction(stmt, _globals));
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
      result.value = !(result.value as bool);
    } else {
      result.value = -(result.value as num);
    }

    result.type = expr.type;
    return result;
  }

  @override
  visitVarStmt(VarStmt stmt) {
    Value value = stmt.type is NamedType ? new NullValue() : new Value(stmt.type, _defaults[stmt.type.name]);
    if (stmt.initializer != null) {
      value = _evaluate(stmt.initializer);
      value.initialized = true;
    }

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
    Value owner = _evaluate(expr.owner);

    if (!owner.initialized) {
      throw new RuntimeError(expr.bracket, "Cannot subscript uninitialized array.");
    }

    int index = _evaluate(expr.index).value as int;
    ArrayValue array = owner as ArrayValue;
    if (index < 0 || index >= array.size) {
      throw new RuntimeError(expr.bracket, "Array index out of bounds.");
    }
    
    return array.get(index); 
  }

  @override
  visitClassStmt(ClassStmt stmt) {
    DecafClass klass = new DecafClass(stmt.name.lexeme);
    _env.define(stmt.name.lexeme, klass);

    DecafClass parent;

    Map<String, Value> fields = {};    
    if (stmt.parent != null) {
      parent = _globals.getAt(0, stmt.parent.lexeme);
      fields = parent.fields;
      klass.constructor = parent.constructor;
    }

    _env = new Environment(_env);

    for (VarStmt field in stmt.fields) {
      _execute(field);
      String name = field.name.lexeme;
      fields[name] = _env.getAt(0, name);
    }

    Map<String, DecafFunction> methods = {};
    for (FunctionStmt method in stmt.methods) {
      _execute(method);
      String name = method.name.lexeme;

      if (method.isConstruct) {
        klass.constructor = _env.getAt(0, name);
      } else {
        methods[name] = _env.getAt(0, name);
      }
    }

    _env = _env.parent;

    klass.fields = fields;
    klass.methods = methods;
    klass.parent = parent;
    
    _env.assign(stmt.name, klass);
  }

  @override
  visitAccessExpr(AccessExpr expr) {
    Value instance = _evaluate(expr.object);
    String field = (expr.field as VariableExpr).name.lexeme;

    if (instance.equalsTo(new NullValue())) {
      throw new RuntimeError(expr.dot, "Cannot access '$field' on null value.");
    }

    if (instance is DecafInstance) {
      return instance.getField(field);
    } else return instance;
  }

  @override
  visitThisExpr(ThisExpr expr) {
    return _env.get(expr.keyword);
  }

  @override
  visitNewExpr(NewExpr expr) {
    DecafClass klass = _globals.getAt(0, expr.type.name);
    DecafInstance instance = new DecafInstance(expr.type, klass);

     if (klass.constructor != null) {
       klass.constructor.bind(instance);
       klass.constructor.callFun(this, expr.args.map((Expr arg) => this._evaluate(arg)).toList());
     }

     return instance;
  }

  @override
  visitReadExpr(ReadExpr expr) {
    String input = stdin.readLineSync();

    return new Value(
      expr.type, 
      BuiltinType.INT.isCompatible(expr.type) 
        ? (int.tryParse(input) ?? 0)
        : input);
  }
  
}