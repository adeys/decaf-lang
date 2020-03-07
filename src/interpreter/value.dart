import '../ast/statement.dart';
import '../types/type.dart';
import 'environmnent.dart';
import 'interpreter.dart';

class Value {
  Object value;
  Type type;

  Value(this.type, [this.value]);

  @override
  String toString() {
    return (type.name == BuiltinType.INT.name) 
      ? (value as num)?.toInt().toString()
      : value.toString();
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
  }

  void set(int index, Value value) {
    value.type = type;
    values[index] = value;
  }

  Value get(int index) {
    return values[index];
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
}

class DecafClass {
  String name;
  Environment scope;

  DecafClass(this.name, [this.scope]);
}

class DecafInstance {
  
}

class Return {
  Value value;
  Return(this.value);
}