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

  Symbol getSymbol(String name) {
    return symbols[name];
  }

  @override
  String toString() {
    return '$type : ${symbols.keys}';
  }
}