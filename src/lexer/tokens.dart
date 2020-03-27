enum TokenType {
	// Single character tokens
	LEFT_PAREN, RIGHT_PAREN, LEFT_BRACE, RIGHT_BRACE,
  LEFT_BRACKET, RIGHT_BRACKET, COMMA, DOT, SEMICOLON, 
  MINUS, PLUS, STAR, SLASH, PERCENT, COLON,
	
	// One or two characters tokens
	BANG, BANG_EQUAL, EQUAL, EQUAL_EQUAL,
	GREATER, GREATER_EQUAL, LESS, LESS_EQUAL,
  AMP_AMP, PIPE_PIPE,

	// Literals
	IDENTIFIER, INTEGER, DOUBLE, STRING,

	// Keywords
	CLASS, THIS, INTERFACE, IMPLEMENTS, IF, ELSE, 
  FOR, WHILE, BREAK, RETURN, TRUE, FALSE, KW_VOID, 
  KW_INT, KW_DOUBLE, KW_STRING, KW_BOOL, NULL, PRINT, 
  RD_LINE, RD_INT, NEW, ARRAY, FUNC,

  WHITESPACE,
  INVALID,
	EOF
}

class Token {
	TokenType type;
	String lexeme;
  Object value;
	int line;

	Token(TokenType type, String lexeme, Object value, int line) {
		this.type = type;
		this.lexeme = lexeme;
    this.value = value;
		this.line = line;
	}

	String toString() {
		return "${type.toString()} $lexeme '${value.toString()}'";
	}
}