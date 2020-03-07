import 'error.dart';

class ErrorReporter {
  static bool hadError = false;
  static bool hadRuntimeError = false;
  
  static void report(Error error) {
    hadError = true;
    if (error is SyntaxError) {
      return _syntaxError(error);
    } else if (error is ParseError) {
      return _parseError(error);
    } else if (error is SemanticError) {
      return _semanticError(error);
    } else if (error is TypeError) {
      return _typeError(error);
    } else if (error is RuntimeError) {
      hadRuntimeError = true;
      return _runtimeError(error);
    } else if (error is CompilerError) {
      print('Execution Error : ${error.message}');
      return;
    }

    throw error;
  }

  static void _syntaxError(SyntaxError error) {
    print('[line ${error.line}] SyntaxError : ' + error.message);
  }

  static void _parseError(ParseError error) {
    print("[line ${error.token.line}] ParseError at '${error.token.lexeme}' : " + error.message);
  }

  static void _semanticError(SemanticError error) {
    print('[line ${error.token.line}] SemanticError : ' + error.message);
  }

  static void _typeError(TypeError error) {
    print('[line ${error.line}] TypeError : ' + error.message);
  }

  static void _runtimeError(RuntimeError error) {
    print('[line ${error.token.line}] RuntimeError : ' + error.message);
  }
}