import '../symbol/scope.dart';

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
  static BuiltinType ERROR = new BuiltinType('undefined');

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
  
  bool isMethodCompatible(FunctionType type) {
    // Check params length
    if (type.paramsType.length != paramsType.length) {
      return false;
    }

    for (int i = 0; i < paramsType.length; i++) {
      if (!(type.paramsType[i].isCompatible(paramsType[i]))) {
        return false;
      }
    }

    return returnType == type.returnType;
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
  Scope scope;
  CustomType parent;

  CustomType(this.name);

  bool hasParent(String type) {
    CustomType _class = parent;
    while (_class != null) {
      if (_class.name == type)
        return true;
      _class = _class.parent;
    }

    return false;
  }

  @override
  bool isCompatible(Type type) {
    if (type == BuiltinType.NULL) return true;

    if (type is! CustomType) return false;

    return type.name == name
      || (type as CustomType).hasParent(name);
  }
  
  @override
  String toString() {
    return name;
  }
}

class TypeTable {
  Map<String, Type> declared = {};

  void addType(Type type) {
    declared[type.name] = type;
  }

  void setType(String name, Type type) {
    declared[name] = type;
    type.name = name;
  }

  Type getType(Type type) {
    return declared[type.name];
  }

  Type getNamedType(String name) {
    return declared[name];
  }

  bool hasNamedType(String name) {
    return declared.keys.contains(name);
  }

  bool hasType(Type type) {
    if (type is BuiltinType || type is FunctionType) {
      return true;
    }

    if (type is ArrayType) {
      while (type is ArrayType) {
        type = (type as ArrayType).base;
      }

      return hasType(type);
    }
    
    return declared.keys.contains(type.name);
  }
}