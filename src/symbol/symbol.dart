import '../types/type.dart';
import 'scope.dart';

class Symbol {
  String name;
  Type type;

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
    current = current.enclosing;
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

/*
  Symbol getSymbol(String symbol) {
    return current.getSymbol(symbol);
  }

  Symbol getFrom(int depth, String symbol) {
    Scope scope = scopes[depth];
    while (scope != null) {
      if (scope.has(symbol)) return scope.getSymbol(symbol);
      scope = scope.enclosing;
    }

    return null;
  }*/
}