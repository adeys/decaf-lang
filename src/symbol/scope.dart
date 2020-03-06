import 'symbol.dart';

class Scope {
  Scope enclosing;
  Map<String, Symbol> symbols = {};

  Scope([this.enclosing]);

  void addSymbol(Symbol symbol) {
    symbols[symbol.name] = symbol;
  }

  bool has(String symbol) {
    return symbols.containsKey(symbol);
  }

  Symbol getSymbol(String name) {
    return symbols[name];
  }
}