import '../ast/statement.dart';
import '../lexer/tokens.dart';
import '../types/type.dart';
import 'environmnent.dart';
import 'interpreter.dart';

class Value {
  Object value;
  Type type;
  bool initialized = false;

  Value(this.type, [this.value]);

  @override
  String toString() {
    return (type.name == BuiltinType.INT.name) 
      ? (value as num)?.toInt().toString()
      : value.toString();
  }

  bool equalsTo(Value value) {
    return this.type.name == value.type.name && this.value == value.value; 
  }
}

class NullValue extends Value {
  NullValue() : super(BuiltinType.NULL, null);
}

class ArrayValue extends Value {
  List<Value> values = [];
  int size;
  ArrayValue(Type type, this.size) : super(type) {
    values = new List<Value>(size);
    values.fillRange(0, size - 1, new Value(type));
    initialized = true;
  }

  void set(int index, Value value) {
    value.type = type;
    values[index] = value;
  }

  Value get(int index) {
    return values[index];
  }

  @override
  bool equalsTo(Value value) {
    return this == value;
  }

  @override
  String toString() {
    return '$type[$size]';
  }
}

abstract class DecafCallable implements Value {
  Value callFun(Interpreter interpreter, List<Value> args);
}

class DecafFunction extends DecafCallable {
  FunctionStmt stmt;
  String name;
  Environment enclosing;

  DecafFunction(this.stmt, this.enclosing);

  Value callFun(Interpreter interpreter, List<Value> args) {
    Environment env = new Environment(enclosing);

    for (int i = 0; i < args.length; i++) {
      env.define(stmt.params[i].name.lexeme, args[i]);
    }

    //print('Called...${stmt.name.lexeme}');
    Value result = new NullValue();
    try {
      interpreter.executeBlock(stmt.body.statements, new Environment(env));      
    } on Return catch (e) {
      result = e.value;
    }

    return result;
  }

  @override
  Type type;

  @override
  Object value;

  @override
  bool equalsTo(Value value) {
    return false;
  }

  @override
  bool initialized = true;
}

class DecafClass {
  String name;
  Environment scope;
  bool hasParent = false;

  DecafClass(this.name, [this.scope]);
}

class DecafInstance implements Value {
  DecafClass _class;

  DecafInstance(this.type, this._class);

  Value getField(String name) {
    Value field = _class.scope.getAt(0, name);
    
    if (field == null && _class.hasParent) {
      return _class.scope.getAt(1, name);
    }

    if (field is DecafFunction) {
      field.enclosing.define('this', this);
    }

    return field;
  }

  void setField(Token name, Value value) {
    _class.scope.assignAt(0, name, value);
  }

  @override
  Type type;

  @override
  Object value;

  @override
  bool equalsTo(Value value) {
    return this == value;
  }

  @override
  bool initialized = true;
}

class Return {
  Value value;
  Return(this.value);
}