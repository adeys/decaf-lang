import '../ast/expression.dart';
import '../ast/statement.dart';
import '../error/error.dart';
import '../error/error_reporter.dart';
import '../lexer/tokens.dart';
import '../types/type.dart';
import 'rules.dart';

Map<TokenType, Type> typeMap = {
  TokenType.KW_INT: BuiltinType.INT,
  TokenType.KW_BOOL: BuiltinType.BOOL,
  TokenType.KW_VOID: BuiltinType.VOID,
  TokenType.KW_DOUBLE: BuiltinType.DOUBLE,
  TokenType.KW_STRING: BuiltinType.STRING
};

class Parser {
  final List<Token> _tokens;
  List<TokenType> _types = [TokenType.KW_INT, TokenType.KW_DOUBLE, TokenType.KW_BOOL, TokenType.KW_STRING];
  Token _previous;
  
  Map<TokenType, ParseRule> _rules = {};

  int offset = 0;

  Parser(this._tokens) {
    _previous = _tokens[0];

    PrefixRule literal = new PrefixRule(Precedence.NONE, _getPrimary);
    PrefixRule unary = new PrefixRule(Precedence.UNARY, _getUnary);
    
    InfixRule equality = new InfixRule(Precedence.EQUALITY);
    InfixRule comparison = new InfixRule(Precedence.COMPARISON);
    InfixRule sum = new InfixRule(Precedence.SUM);
    InfixRule product = new InfixRule(Precedence.PRODUCT);
    
    _rules = {
      // Literals
      TokenType.NULL: literal,
      TokenType.TRUE: literal,
      TokenType.FALSE: literal,
      TokenType.STRING: literal,
      TokenType.DOUBLE: literal,
      TokenType.INTEGER: literal,
      TokenType.IDENTIFIER: literal,
      TokenType.THIS: literal,

      // Unary
      TokenType.BANG: unary,

      // Misc
      TokenType.LEFT_BRACKET: new InfixRule(Precedence.CALL, null, _getIndex),
      TokenType.LEFT_PAREN: new InfixRule(Precedence.CALL, _getGroupingExpr, _getCall),
      TokenType.ARRAY: new PrefixRule(Precedence.NONE, _getArrayExpr),
      TokenType.DOT: new InfixRule(Precedence.CALL, null, _getDot),

      // Binary
      TokenType.EQUAL: new InfixRule(Precedence.ASSIGNMENT, null, _getAssignment),
      TokenType.EQUAL_EQUAL: equality,
      TokenType.BANG_EQUAL: equality,

      TokenType.LESS: comparison,
      TokenType.LESS_EQUAL: comparison,
      TokenType.GREATER: comparison,
      TokenType.GREATER_EQUAL: comparison,

      TokenType.AMP_AMP: new InfixRule(Precedence.AND, null, _getLogical),
      TokenType.PIPE_PIPE: new InfixRule(Precedence.OR, null, _getLogical),

      TokenType.PLUS: sum,
      TokenType.MINUS: new InfixRule(Precedence.SUM, _getUnary, _getBinary),
      TokenType.STAR: product,
      TokenType.SLASH: product,
      TokenType.PERCENT: product
    };
  }

  List<Stmt> parse() {
    List<Stmt> ast = [];

    while (!isAtEnd()) {
      ast.add(_getDeclaration());
    }

    return ast;
  }

  Stmt _getDeclaration() {
    try {
      if (_match([TokenType.CLASS])) return _getClassDeclaration();

      return _getFieldDeclaration();
    } on ParseError catch (e) {
      ErrorReporter.report(e);
      _synchronize();
      return null;
    }
  }

  Stmt _getFieldDeclaration() {
    int index = offset;
    Type type = _match([TokenType.KW_VOID]) ? BuiltinType.VOID : _expectType();
    Token name = _expect(TokenType.IDENTIFIER, 'Expect variable name after type.');
    
    if (type.name == BuiltinType.VOID.name || _check(TokenType.LEFT_PAREN)) {
      _expect(TokenType.LEFT_PAREN, "Expect '(' after function name in function declaration.");
      return _getFuncDeclaration(type, name);
    }

    offset = index;
    return _getVarDeclaration();
  }

  ClassStmt _getClassDeclaration() {
    Token name = _expect(TokenType.IDENTIFIER, "Expect class name.");
    Token parent;
    
    if (_match([TokenType.EXTENDS])) {
      parent = _expect(TokenType.IDENTIFIER, "Expect parent class name.");
    }

    List<VarStmt> fields = [];
    List<FunctionStmt> methods = [];
    _expect(TokenType.LEFT_BRACE, "Expect '{' before class declaration body.");
    while (!_check(TokenType.RIGHT_BRACE)) {
      Stmt field = _getFieldDeclaration();
      (field is VarStmt ? fields : methods).add(field);
    }
    _expect(TokenType.RIGHT_BRACE, "Expect '}' at class declaration end.");

    return new ClassStmt(name, parent, fields, methods);
  }

  VarStmt _getVariable() {
    Type type = _expectType();
    Token name = _expect(TokenType.IDENTIFIER, 'Expect variable name after type.');

    return new VarStmt(type, name, null);
  }

  VarStmt _getVarDeclaration() {
    VarStmt stmt = _getVariable();

    if (_match([TokenType.EQUAL])) {
      stmt.initializer = _getExpression();
    }

    _expect(TokenType.SEMICOLON, "Expect ';' after variable declaration.");
    return stmt;
  }

  FunctionStmt _getFuncDeclaration(Type returnType, Token name) {
    // Consume parameters list
    
    List<VarStmt> params = [];
    if (!_check(TokenType.RIGHT_PAREN)) {
      do {
        params.add(_getVariable());
      } while (_match([TokenType.COMMA]));
    }

    _expect(TokenType.RIGHT_PAREN, "Expect ')' after function parameters list.");
    _expect(TokenType.LEFT_BRACE, "Expect '{' at function body start.");

    BlockStmt body = _getBlockStatement();

    return new FunctionStmt(name, params, returnType, body);
  }

  // Statements parsing functions
  Stmt _getStatement() {
    if (_match([TokenType.IF])) return _getIfStatement();
    if (_match([TokenType.FOR])) return _getForStatement();
    if (_match([TokenType.BREAK])) return _getBreakStatement();
    if (_match([TokenType.PRINT])) return _getPrintStatement();
    if (_match([TokenType.WHILE])) return _getWhileStatement();
    if (_match([TokenType.RETURN])) return _getReturnStatement();
    if (_match([TokenType.LEFT_BRACE])) return _getBlockStatement();

    return _getExpressionStmt();
  }

  IfStmt _getIfStatement() {
    Token keyword = _previous;
    _expect(TokenType.LEFT_PAREN, "Expect '(' before if conditional expression.");
    Expr condition = _getExpression();
    _expect(TokenType.RIGHT_PAREN, "Expect ')' after if conditional expression.");

    Stmt ifBranch = _getStatement();

    Stmt elseBranch;
    if (_match([TokenType.ELSE])) {
      elseBranch = _getStatement();
    }

    return new IfStmt(keyword, condition, ifBranch, elseBranch);
  }

  ForStmt _getForStatement() {
    Token keyword = _previous;

    _expect(TokenType.LEFT_PAREN, "Expect '(' after 'for' keyword.");
    
    Expr initializer;
    if (!_match([TokenType.SEMICOLON])) {
      initializer = _getExpression();
      _expect(TokenType.SEMICOLON, "Expect ';' after for-loop initializer.");
    }

    Expr condition = _getExpression();
    _expect(TokenType.SEMICOLON, "Expect ';' after for-loop condition.");

    Expr incrementer;
    if (!_check(TokenType.RIGHT_PAREN)) {
      incrementer = _getExpression();
    }

    _expect(TokenType.RIGHT_PAREN, "Expect ')' after 'for' initializer.");

    Stmt body = _getStatement();

    return new ForStmt(keyword, initializer, condition, incrementer, body);
  }


  BreakStmt _getBreakStatement() {
    Token keyword = _previous;
    _expect(TokenType.SEMICOLON, "Expect ';' after break statement.");

    return new BreakStmt(keyword);
  }

  PrintStmt _getPrintStatement() {
    Token keyword = _previous;
    List<Expr> exprs = [];

    _expect(TokenType.LEFT_PAREN, "Expect '(' after 'print'.");
    
    do {
      exprs.add(_getExpression());
    } while (_match([TokenType.COMMA]));

    _expect(TokenType.RIGHT_PAREN, "Expect ')' after print arguments list.");
    _expect(TokenType.SEMICOLON, "Expect ';' after print statement.");

    return new PrintStmt(keyword, exprs);
  }

	WhileStmt _getWhileStatement() {
		Token keyword = _previous;
    _expect(TokenType.LEFT_PAREN, "Expect '(' after while.");
		Expr condition = _getExpression();

		_expect(TokenType.RIGHT_PAREN, "Expect ')' after condition.");
		Stmt body = _getStatement();

		return new WhileStmt(keyword, condition, body);
	}

  ReturnStmt _getReturnStatement() {
    Token keyword = _previous;
    Expr expr;

    if (!_check(TokenType.SEMICOLON)) {
      expr = _getExpression();
    }

    _expect(TokenType.SEMICOLON, "Expect ';' after return statement.");

    return new ReturnStmt(keyword, expr);
  }

  BlockStmt _getBlockStatement() {
    List<Stmt> statements = [];

    while (!_check(TokenType.RIGHT_BRACE)) {
      statements.add(_matchType() ? _getVarDeclaration() : _getStatement());
    }

    _expect(TokenType.RIGHT_BRACE, "Expect '}' at block end.");

    return new BlockStmt(statements);
  }

  ExpressionStmt _getExpressionStmt() {
    Expr expr = _getExpression();
    _expect(TokenType.SEMICOLON, "Expect ';' after expression.");

    return new ExpressionStmt(expr);
  }

  // Expressions parsing
  Expr _getExpression() {
    if (_match([TokenType.NEW])) return _getNewExpr();
    if (_match([TokenType.RD_INT, TokenType.RD_LINE])) return _getReadExpr();

    return _parsePrecedence(Precedence.NONE);
  }

  NewExpr _getNewExpr() {
    Token keyword = _previous;

    _expect(TokenType.LEFT_PAREN, "Expect '(' after 'new'.");
    Type type = _expectType(false);
    _expect(TokenType.RIGHT_PAREN, "Expect ')' after new expression.");

    return new NewExpr(keyword, type);
  }

  ReadExpr _getReadExpr() {
    Token keyword = _previous;
    String name = keyword.type == TokenType.RD_INT ? 'readInt' : 'readLine';

    _expect(TokenType.LEFT_PAREN, "Expect '(' after '$name'.");
    _expect(TokenType.RIGHT_PAREN, "Expect ')' after $name expression.");

    return new ReadExpr(keyword, keyword.type == TokenType.RD_INT ? BuiltinType.INT : BuiltinType.STRING);
  }

  Expr _parsePrecedence(int precedence, [bool assoc = true]) {
    Token current = _peek();

    ParseRule rule = _rules[current.type];
    if (rule == null || rule.prefix == null) {
      throw new ParseError(current, "Expected expression.");
    }

    Expr left = rule.prefix();
    
    int currPrec;
    while ((currPrec = _getPrecedence(_peek())) > precedence) {
      _advance();
      left = (_rules[_previous.type].postfix ?? _getBinary)(left, currPrec);
    }

    return left;
  }

  int _getPrecedence(Token token) {
    return _rules[token.type]?.precedence ?? -1;
  }

  LogicalExpr _getLogical(Expr left, int nextPrecedence) {
    Token op = _previous;
    Expr right = _parsePrecedence(nextPrecedence);
    
    return new LogicalExpr(op, left, right);
  }

  BinaryExpr _getBinary(Expr left, int nextPrecedence) {
    Token op = _previous;
    Expr right = _parsePrecedence(nextPrecedence);
    
    return new BinaryExpr(op, left, right);
  }

  UnaryExpr _getUnary() {
    Token op = _advance();
    Expr right = _parsePrecedence(Precedence.UNARY);

    return new UnaryExpr(op, right);
  }

  GroupingExpr _getGroupingExpr() {
    // Consume '('
    _advance();
    Expr expression = _getExpression();
    _expect(TokenType.RIGHT_PAREN, "Expect ')' after group expression.");

    return new GroupingExpr(expression);
  }

  ArrayExpr _getArrayExpr() {
    Token keyword = _advance();

    _expect(TokenType.LEFT_PAREN, "Expect '(' after 'array'.");
    Expr size = _getExpression();
    _expect(TokenType.COMMA, "Expect ',' after array size.");
    Type type = _expectType(false);
    _expect(TokenType.RIGHT_PAREN, "Expect ')' after 'array' expression.");

    return new ArrayExpr(keyword, type, size);
  }

  AccessExpr _getDot(Expr target, int precedence) {
    Token dot = _previous;
    Expr field = _parsePrecedence(Precedence.CALL * 2);

    return new AccessExpr(dot, target, field);
  }

  AssignExpr _getAssignment(Expr left, int _) {
    if (left is! VariableExpr && left is! IndexExpr && left is! AccessExpr) 
      throw new ParseError(_previous, "Invalid assignment target.");

    Token keyword = _previous;
    Expr value = _getExpression();//_parsePrecedence(Precedence.ASSIGNMENT);

    return new AssignExpr(keyword, left, value);
  }

  IndexExpr _getIndex(Expr left, int precedence) {
    Token keyword = _previous;
    Expr index = _getExpression();

    _expect(TokenType.RIGHT_BRACKET, "Expected ']' after index access");

    return new IndexExpr(keyword, left, index);
  }

  CallExpr _getCall(Expr callee, int _) {
    Token paren = _previous;
    List<Expr> params = [];
    if (!_check(TokenType.RIGHT_PAREN)) {
      do {
        params.add(_getExpression());
      } while (_match([TokenType.COMMA]));
    }

    _expect(TokenType.RIGHT_PAREN, "Expect ')' after call parameters.");

    return new CallExpr(paren, callee, params);
  }

  Expr _getPrimary() {
      if (_match([TokenType.NULL])) return new LiteralExpr(BuiltinType.NULL, null);
      if (_match([TokenType.TRUE])) return new LiteralExpr(BuiltinType.BOOL, true);
      if (_match([TokenType.FALSE])) return new LiteralExpr(BuiltinType.BOOL, false);
      if (_match([TokenType.INTEGER])) return new LiteralExpr(BuiltinType.INT, _previous.value);
      if (_match([TokenType.DOUBLE])) return new LiteralExpr(BuiltinType.DOUBLE, _previous.value);
      if (_match([TokenType.STRING])) return new LiteralExpr(BuiltinType.STRING, _previous.value);
      if (_match([TokenType.IDENTIFIER])) return new VariableExpr(_previous);
      if (_match([TokenType.THIS])) return new ThisExpr(_previous);
      
      throw new ParseError(_peek(), "Expected constant or variable expression.");
  }

  // Parsing functions

  void _synchronize() {
		_advance();

		while (!isAtEnd()) {
			if (_previous.type == TokenType.EOF) return;

			switch (_peek().type) {
				case TokenType.KW_BOOL:
				case TokenType.KW_INT:
				case TokenType.KW_VOID:
				case TokenType.KW_DOUBLE:
				case TokenType.KW_STRING:
				case TokenType.CLASS:
				//case TokenType.IF:
				//case TokenType.ELSE:
				case TokenType.FOR:
				//case TokenType.WHILE:
				//case TokenType.PRINT:
				//case TokenType.RETURN:
					return;
				default:
					_advance();
			}
		}
	}


  bool _check(TokenType type) {
    if (isAtEnd()) return false;

    return _peek().type == type;
  }

  bool _checkNext(TokenType type) {
    if (isAtEnd()) return false;

    return _tokens[offset + 1].type == type;
  }

  bool _match(List<TokenType> types) {
    if (isAtEnd()) return false;

    Token curr = _peek();
    for (TokenType type in types) {
      if (curr.type == type) {
        _advance();
        return true;
      }  
    }
    return false;
  }

  bool _matchType([bool declare = true]) {
    // Match cases: `Class name` and `Class[]` 
    if (_check(TokenType.IDENTIFIER)) {
      // Trick to match a single identifier as a type name
      if (!declare) return true;
      
      if (_checkNext(TokenType.IDENTIFIER)) {
        return true;
      } else if (_checkNext(TokenType.LEFT_BRACKET)) {
        _advance();
        if (_checkNext(TokenType.RIGHT_BRACKET)) {
          offset--;
          return true;
        }
        offset--;
        return false;
      }
      return false;
    }

    if (_match(_types)) {
      // Rollback offset
      offset--;
      
      if (_check(TokenType.LEFT_BRACKET) && _checkNext(TokenType.RIGHT_BRACKET)) {
        return true;
      }

      return true;
    }

    return false;
  }

  Token _expect(TokenType type, String errMsg) {
    if (_check(type)) {
      return _advance();
    }

    throw new ParseError(_peek(), errMsg);
  }

  Type _expectType([bool declare = true]) {
    if (!_matchType(declare)) {
      throw new ParseError(_peek(), 'Expected type expression.');
    }

    _advance();
    Type type = typeMap[_previous.type];
    if (type == null) {
      type = new CustomType(_previous.lexeme);
    }

    while (_match([TokenType.LEFT_BRACKET])) {
      _expect(TokenType.RIGHT_BRACKET, "Expected ']' after '[' in type declaration.");
      type = new ArrayType(type);
    }
    
    return type;
  }

  Token _advance() {
    _previous = _peek();
    offset++;
    return _previous;
  }

  Token _peek() {
    return _tokens[offset];
  }

  bool isAtEnd() {
    return _peek().type == TokenType.EOF;
  }
}