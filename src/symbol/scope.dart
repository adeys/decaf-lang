import 'symbol.dart';

enum ScopeType {
  GLOBAL,
  FORMALS,
  BLOCK,
  CLASS
}

class Scope {
  Scope enclosing;
  ScopeType type;
  Map<String, Symbol> symbols = {};

  Scope(this.type, [this.enclosing]);

  void addSymbol(Symbol symbol) {
    symbols[symbol.name] = symbol;
  }

  bool has(String symbol) {
    return symbols.containsKey(symbol);
  }

  bool classHas(String symbol) {
    Scope current = this; 

    while (current != null) {
      if (current.has(symbol))
        return true;
      current = current.enclosing;
    }

    return false;
  }

  Symbol getSymbol(String name) {
    return symbols[name];
  }

  Symbol getClassSymbol(String name) {
    Scope current = this; 

    while (current != null) {
      if (current.has(name))
        return current.getSymbol(name);
      current = current.enclosing;
    }

    return null;
  }

  @override
  String toString() {
    return '$type : ${symbols.keys}';
  }
}