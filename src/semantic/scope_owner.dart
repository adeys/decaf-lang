import '../symbol/scope.dart';
import '../symbol/symbol.dart';

class ScopeOwner {
  SymbolTable table;
  Scope current;
  int index = 0;

  ScopeOwner(this.table) {
    current = table.scopes[0];
  }

  void beginScope() {
    index++;
    current = table.scopes[index];
  }

  void endScope() {
    current = current.type == ScopeType.CLASS ? table.scopes[0] : current.enclosing;
  }

  Symbol fromCurrent(String symbol) {
    return current.getSymbol(symbol);
  }

  Symbol getAt(int depth, String symbol) {
    return table.scopes[depth].getSymbol(symbol);
  }

  Symbol getSymbol(String symbol) {
    Scope scope = current;
    while (scope != null) {
      if (scope.has(symbol)) return scope.getSymbol(symbol);
      scope = scope.enclosing;
    }

    return null;
  }
}