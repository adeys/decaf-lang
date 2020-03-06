
import '../lexer/tokens.dart';

class Error {
  String message;

  Error(this.message);
}

class SyntaxError extends Error {
  int line;

  SyntaxError(this.line, String message): super(message);
}

class ParseError extends Error {
  Token token;

  ParseError(this.token, String message): super(message);
}