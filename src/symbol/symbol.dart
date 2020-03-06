class Symbol {
  String name;
  Type type;

  Symbol(this.name, [this.type]);
}

class SymbolTable {
  List<Map<String, Symbol>> _symbols = [];
  int scope = -1;

  void beginScope() {
    _symbols.add(new Map<String, Symbol>());
    scope++;
  }

  void endScope() {
    scope--;
  }

  void addSymbol(Symbol symbol) {
    _symbols[scope][symbol.name] = symbol;
  }

  bool inScope(String symbol) {
    return _symbols[scope].containsKey(symbol);
  }

  bool hasSymbol(String symbol) {
    for (int i = scope; i >= 0; i--) {
      if (_symbols[i].containsKey(symbol)) {
        return true;
      }
    }

    return false;
  }

  Symbol getSymbol(String symbol) {
    return _symbols[scope][symbol];
  }
}