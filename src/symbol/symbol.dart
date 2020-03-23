import '../types/type.dart';
import 'scope.dart';

class Symbol {
  String name;
  Type type;
  bool initialized = false;

  Symbol(this.name, [this.type]);
}

class SymbolTable {
  List<Scope> scopes = [];
  Scope current;
  TypeTable types = new TypeTable();

  void beginScope(ScopeType type) {
    current = new Scope(type, current);
    scopes.add(current);
  }

  void endScope() {
    current = current.type == ScopeType.CLASS ? scopes[0] : current.enclosing;
  }

  void addSymbol(Symbol symbol) {
    current.addSymbol(symbol);
  }

  void setSymbol(String name, Symbol symbol) {
    current.symbols[name] = symbol;
  }

  bool inScope(String symbol) {
    return current.has(symbol);
  }

  bool hasSymbol(String symbol) {
    Scope scope = current;
    while( scope != null) {
      // Disable field access without 'this' keyword in method body
      if (scope.type == ScopeType.CLASS && scope.has(symbol)) {
        return false;
      }
      if (scope.has(symbol)) return true;
      scope = scope.enclosing;
    }

    return false;
  }

  Symbol getAt(int depth, String symbol) {
    return scopes[depth].getSymbol(symbol);
  }

  void registerType(Type type) {
    types.addType(type);
  }

  void updateType(Type type) {
    types.setType(type.name, type);
  }

  bool typeExists(String name) {
    return types.hasNamedType(name);
  }

  Type getType(String name) {
    return types.getNamedType(name);
  }
/*
  Symbol getSymbol(String symbol) {
    return current.getSymbol(symbol);
  }
*/
  Symbol getSymbol(String symbol) {
    Scope scope = current;
    while (scope != null) {
      if (scope.has(symbol)) return scope.getSymbol(symbol);
      scope = scope.enclosing;
    }

    return null;
  }
}