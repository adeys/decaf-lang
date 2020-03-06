class Type {
}

class BuiltinType extends Type {
  String name;

  static BuiltinType INT = new BuiltinType('int');
  static BuiltinType BOOL = new BuiltinType('bool');
  static BuiltinType VOID = new BuiltinType('void');
  static BuiltinType STRING = new BuiltinType('string');
  static BuiltinType DOUBLE = new BuiltinType('double');
  static BuiltinType NULL = new BuiltinType('null');

  BuiltinType(this.name);

  @override
  String toString() {
    return name;
  }
}

class FunctionType extends Type {
  
}
