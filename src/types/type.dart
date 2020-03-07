abstract class Type {
  String name;
  bool isCompatible(Type type);
}

class BuiltinType extends Type {
  String name;

  static BuiltinType INT = new BuiltinType('int');
  static BuiltinType BOOL = new BuiltinType('bool');
  static BuiltinType VOID = new BuiltinType('null');
  static BuiltinType STRING = new BuiltinType('string');
  static BuiltinType DOUBLE = new BuiltinType('double');
  static BuiltinType NULL = new BuiltinType('null');
  static BuiltinType ERROR = new BuiltinType('error');

  BuiltinType(this.name);

  @override
  String toString() {
    return name;
  }

  @override
  bool isCompatible(Type type) {
    if (type is BuiltinType) return type.name == 'error' || name == type.name;

    return false;
  }
}

class FunctionType extends Type {
  String name = 'function';
  Type returnType;
  List<Type> paramsType;

  FunctionType(this.returnType, this.paramsType);

  @override
  bool isCompatible(Type type) {
    return false;
  }
  
  @override
  String toString() {
    return name;
  }
}

class ArrayType extends Type {
  String name;
  Type base;
  
  ArrayType(this.base) {
    name = '$base[]';
  }

  @override
  bool isCompatible(Type type) {
    return (type is ArrayType) && type.name == name;
  }
  
  @override
  String toString() {
    return name;
  }
}

class CustomType extends Type {
  String name;

  CustomType(this.name);

  @override
  bool isCompatible(Type type) {
    return type is CustomType && type.name == name;
  }
  
  @override
  String toString() {
    return name;
  }
}