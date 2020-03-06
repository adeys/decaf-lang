import '../ast/expression.dart';
import '../ast/statement.dart';
import '../error/error.dart';
import '../lexer/tokens.dart';
import '../types/type.dart';

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
  int offset = 0;

  Parser(this._tokens) {
    _previous = _tokens[0];
  }

  List<Stmt> parse() {
    List<Stmt> ast = [];

    while (!isAtEnd()) {
      ast.add(_getDeclaration());
    }

    return ast;
  }

  Stmt _getDeclaration() {
    if (_matchReturnType()) {
      Token type = _previous;
      Token name = _expect(TokenType.IDENTIFIER, 'Expect name after type.');
      
      if (type.type != TokenType.KW_VOID && _match([TokenType.SEMICOLON])) 
        return new VarStmt(typeMap[type.type], name, null);
      
      _expect(TokenType.LEFT_PAREN, "Expect '(' after function name in function declaration.");
      return _getFuncDeclaration(type, name);
    }
    
    throw new ParseError(_peek(), "Unexpected token '${_peek().lexeme}'");
  }

  VarStmt _getVariable() {
    Token type = _expectType();
    Token name = _expect(TokenType.IDENTIFIER, 'Expect variable name after type.');

    return new VarStmt(typeMap[type.type], name, null);
  }

  VarStmt _getVarDeclaration() {
    VarStmt stmt = _getVariable();

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

    return new FunctionStmt(name, params, typeMap[returnType], body.statements);
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
    Token keyword;
    _expect(TokenType.SEMICOLON, "Expect ';' after break statement.");

    return new BreakStmt(keyword);
  }

  PrintStmt _getPrintStatement() {
    Token keyword = _previous;
    List<Expr> exprs = [];

    _expect(TokenType.LEFT_PAREN, "Expect '(' after 'print'.");
    
    do {
      exprs.add(_getExpression());
    } while (!_check(TokenType.COMMA));

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

  }

  // Parsing functions
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