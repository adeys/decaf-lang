import 'error.dart';

class ErrorReporter {
  static bool hadError = false;
  
  static void report(Error error) {
    if (error is SyntaxError) {
      return syntaxError(error);
    } else if (error is ParseError) {
      return parseError(error);
    }

    throw error;
  }

  static void syntaxError(SyntaxError error) {
    print('[line ${error.line}] SyntaxError : ' + error.message);
  }

  static void parseError(ParseError error) {
    print('[line ${error.token.line}] ParseError : ' + error.message);
  }
}