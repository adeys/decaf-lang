
import '../lexer/tokens.dart';

class CompilerError extends Error {
  String message;

  CompilerError(this.message);
}

class SyntaxError extends CompilerError {
  int line;

  SyntaxError(this.line, String message): super(message);
}

class ParseError extends CompilerError {
  Token token;

  ParseError(this.token, String message): super(message);
}