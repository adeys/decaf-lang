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

    //InfixRule dot = new InfixRule(Precedence.CALL, null, _getDot);
    InfixRule group = new InfixRule(Precedence.CALL, _getGroupingExpr, _getCall);
    
    InfixRule assign = new InfixRule(Precedence.ASSIGNMENT, null, _getAssignment);
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

      // Unary
      TokenType.MINUS: unary,
      TokenType.BANG: unary,

      // Misc
      TokenType.LEFT_PAREN: group,
      //TokenType.DOT: dot,

      // Binary
      TokenType.EQUAL: assign,
      TokenType.EQUAL_EQUAL: equality,
      TokenType.BANG_EQUAL: equality,

      TokenType.LESS: comparison,
      TokenType.LESS_EQUAL: comparison,
      TokenType.GREATER: comparison,
      TokenType.GREATER_EQUAL: comparison,

      TokenType.AMP_AMP: new InfixRule(Precedence.AND, null, _getLogical),
      TokenType.PIPE_PIPE: new InfixRule(Precedence.OR, null, _getLogical),

      TokenType.PLUS: sum,
      TokenType.MINUS: sum,
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
      if (_matchReturnType()) {
        Token type = _previous;
        Token name = _expect(TokenType.IDENTIFIER, 'Expect name after type.');
        
        if (type.type != TokenType.KW_VOID && !_check(TokenType.LEFT_PAREN)) {
          // If the type is not 'void' and we dont have a '(' after symbol name
          // rewind and get a variable declaration
          offset -= 2;
          return _getVarDeclaration();
        }
        
        _expect(TokenType.LEFT_PAREN, "Expect '(' after function name in function declaration.");
        return _getFuncDeclaration(type, name);
      }
      
      throw new ParseError(_peek(), "Unexpected token '${_peek().lexeme}'");
    } on ParseError catch (e) {
      ErrorReporter.report(e);
      _synchronize();
      return null;
    }
  }

  VarStmt _getVariable() {
    Token type = _expectType();
    Token name = _expect(TokenType.IDENTIFIER, 'Expect variable name after type.');

    return new VarStmt(typeMap[type.type], name, null);
  }

  VarStmt _getVarDeclaration() {
    VarStmt stmt = _getVariable();

    if (_match([TokenType.EQUAL])) {
      stmt.initializer = _getPrimary();
    }

    _expect(TokenType.SEMICOLON, "Expect ';' after variable declaration.");
    return stmt;
  }

  FunctionStmt _getFuncDeclaration(Token returnType, Token name) {
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

    return new FunctionStmt(name, params, typeMap[returnType], body);
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
      statements.add(_types.contains(_peek().type) ? _getVarDeclaration() : _getStatement());
    }

    _expect(TokenType.RIGHT_BRACE, "Expect '}' at block end.");

    return new BlockStmt(statements);
  }

  ExpressionStmt _getExpressionStmt() {
    Expr expr = _getExpression();
    _expect(TokenType.SEMICOLON, "Unexpected '${_peek().lexeme}'. Expect ';' after expression.");

    return new ExpressionStmt(expr);
  }

  // Expressions parsing
  Expr _getExpression() {
    return _parsePrecedence(Precedence.NONE);
  }

  Expr _parsePrecedence(int precedence, [bool assoc = true]) {
    Token current = _peek();

    ParseRule rule = _rules[current.type];
    if (rule == null || rule.prefix == null) {
      throw new ParseError(current, "Unexpected '${current.lexeme}'. Expected expression.");
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

  AssignExpr _getAssignment(Expr left, int _) {
    if (left is! VariableExpr) throw new ParseError(_previous, "Invalid assignment target.");

    Token keyword = _previous;
    Expr value = _parsePrecedence(Precedence.ASSIGNMENT);

    return new AssignExpr(keyword, left, value);
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
      
      throw new ParseError(_peek(), "Unexpected '${_peek().lexeme}' Expected constant or variable expression.");
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
				//case TokenType.FOR:
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

  bool _matchType() {
    return _match(_types);
  }

  bool _matchReturnType() {
    return _match([TokenType.KW_VOID] + _types);
  }

  Token _expect(TokenType type, String errMsg) {
    if (_peek().type == type) {
      return _advance();
    }

    throw new ParseError(_peek(), errMsg);
  }

  Token _expectType() {
    if (!_matchType()) {
      throw new ParseError(_peek(), 'Expect expression type.');
    }

    return _previous;
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