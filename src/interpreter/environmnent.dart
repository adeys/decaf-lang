
import '../error/error.dart';
import '../lexer/tokens.dart';

class Environment {
	Map<String, Object> store = new Map<String, Object>();
	Environment parent = null;

	Environment([Environment _parent = null]) {
		parent = _parent;
	}

	void define(String name, Object value) {
		store[name] = value;
	}

	void assign(Token name, Object value) {
		if (store.containsKey(name.lexeme)) {
			store[name.lexeme] =  value;
			return;
		}

		if (parent != null) {
			parent.assign(name, value);
			return;
		}

		throw new RuntimeError(name, "Undefined variable '${name.lexeme}'.");
	}

	void assignAt(int dist, Token name, Object value) {
		_ancestor(dist).store[name.lexeme] = value;
	}

	Object get(Token name) {
		if (store.containsKey(name.lexeme)) {
			return store[name.lexeme];
		}

		if (parent != null) return parent.get(name);

		throw new RuntimeError(name, "Undefined variable '${name.lexeme}'.");
	}

	Object getAt(int dist, String name) {
		return _ancestor(dist).store[name];
	}

	Environment _ancestor(int depth) {
		Environment env = this;
		for (int i = 0; i < depth; i++) {
			env = env.parent;
		}

		return env;
	}
}