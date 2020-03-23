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
    if (this.type is CustomType && !this.initialized) {
      return value.type.name == BuiltinType.NULL.name;
    } else if (value.type is CustomType && !value.initialized) {
      return this.type.name == BuiltinType.NULL.name;
    }

    return this.type.name == value.type.name && this.value == value.value; 
  }
}

class NullValue extends Value {
  NullValue() : super(BuiltinType.NULL, null);
}

class ArrayValue extends Value {
  List<Value> values = [];
  int size;
  Type base;

  ArrayValue(ArrayType type, this.size) : super(type) {
    values = new List<Value>(size);
    base = type.base;
    values.fillRange(0, size - 1, new Value(base));
    initialized = true;
  }

  void set(int index, Value value) {
    value.type = base;
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
  DecafInstance bound;

  DecafFunction(this.stmt, this.enclosing);

  Value callFun(Interpreter interpreter, List<Value> args) {
    Environment env = new Environment(enclosing);

    if (this.bound != null) {
      env.define('this', bound);
    }

    for (int i = 0; i < args.length; i++) {
      env.define(stmt.params[i].name.lexeme, args[i]);
    }

    Value result = new NullValue();
    try {
      interpreter.executeBlock(stmt.body.statements, new Environment(env));      
    } on Return catch (e) {
      result = e.value;
    }

    return result;
  }

  void bind(DecafInstance instance) {
    bound = instance;
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
  Map<String, Value> fields = {};
  Map<String, DecafFunction> methods = {};
  Environment scope;
  DecafClass parent;

  DecafClass(this.name, [this.fields, this.methods, this.scope]);

  Value getMethod(String name) {
    DecafFunction field = methods[name];

    if (field == null && parent != null) {
      field = parent.getMethod(name);
    }

    return field;
  }
}

class DecafInstance implements Value {
  DecafClass _class;
  Map<String,Value> fields = {};

  DecafInstance(this.type, this._class) {
    Value value = new NullValue();

    _class.fields.keys.forEach((String key) {
      fields[key] = value;
    });
  }

  Value getField(String name) {
    if (fields.containsKey(name)) {
      return fields[name];
    }

    Value field = _class.getMethod(name);

    if (field is DecafFunction) {
      field.bind(this);
    }

    return field;
  }

  void setField(Token name, Value value) {
    fields[name.lexeme] = value;
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
  String toString() {
    return _class.toString() + ' instance';
  }

  @override
  bool initialized = true;
}

class Return {
  Value value;
  Return(this.value);
}