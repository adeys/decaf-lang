import '../types/type.dart';

class Value {
  Type type;
}

class LiteralValue extends Value {
  Object value;
  Type type;

  LiteralValue(this.type, this.value);
}

class NullValue extends LiteralValue {
  NullValue() : super(BuiltinType.NULL, null); 
}