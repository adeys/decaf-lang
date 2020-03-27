import '../error/error.dart';
import '../error/error_reporter.dart';
import 'tokens.dart';

class Lexer {
  final String source;
  int line = 1;
  int offset = 0;
  int start = 0;
  List<Token> tokens = [];
  
  List<String> _escapers = ['n', 't', 'b', 'r', '\\', '"'];
  
  Map<String, TokenType> _keywords = {
    "int": TokenType.KW_INT,
    "double": TokenType.KW_DOUBLE,
    "string": TokenType.KW_STRING,
    "bool": TokenType.KW_BOOL,
    "void": TokenType.KW_VOID,
    "true": TokenType.TRUE,
    "false": TokenType.FALSE,
    "class": TokenType.CLASS,
    //"interface": TokenType.INTERFACE,
    "null": TokenType.NULL,
    "this": TokenType.THIS,
    //"implements": TokenType.IMPLEMENTS,
    "for": TokenType.FOR,
    "while": TokenType.WHILE,
    "if": TokenType.IF,
    "else": TokenType.ELSE,
    "return": TokenType.RETURN,
    "break": TokenType.BREAK,
    "new": TokenType.NEW,
    "array": TokenType.ARRAY,
    "func": TokenType.FUNC,
    "print": TokenType.PRINT,
    "readInt": TokenType.RD_INT,
    "readLine": TokenType.RD_LINE,
  };

  Lexer(this.source);

  List<Token> tokenize() {
    while (!isAtEnd()) {
      start = offset;
      getToken();
    }

    tokens.add(new Token(TokenType.EOF, 'EOF', null, line));
    return tokens;
  }

  void getToken() {
    String char = _advance();

    switch (char) {
      case '(': _addToken(TokenType.LEFT_PAREN, char); break;
      case ')': _addToken(TokenType.RIGHT_PAREN, char); break;
      case '{': _addToken(TokenType.LEFT_BRACE, char); break;
      case '}': _addToken(TokenType.RIGHT_BRACE, char); break;
      case '[': _addToken(TokenType.LEFT_BRACKET, char); break;
      case ']': _addToken(TokenType.RIGHT_BRACKET, char); break;
      case ',': _addToken(TokenType.COMMA, char); break;
      case '.': _addToken(TokenType.DOT, char); break;
      case ';': _addToken(TokenType.SEMICOLON, char); break;
      case ':': _addToken(TokenType.COLON, char); break;
      case '+': _addToken(TokenType.PLUS, char); break;
      case '-': _addToken(TokenType.MINUS, char); break;
      case '*': _addToken(TokenType.STAR, char); break;
      case '%': _addToken(TokenType.PERCENT, char); break;
      case '/': {
        if (_peek() == '/') {
          while (_peek() != '\n' && !isAtEnd()) _advance();
          break;
        }

        if (_peek() == "*") {
          _advance();
          _matchMultilineComment();
          break;
        }

        _addToken(TokenType.SLASH, char);
        break;
      }
      case '!': {
        bool two = _match('=');
        _addToken(two ? TokenType.BANG_EQUAL : TokenType.BANG, two ? '!=' : char);
        break;
      }
      case '=': {
        bool two = _match('=');
        _addToken(two ? TokenType.EQUAL_EQUAL : TokenType.EQUAL, two ? '==' : char);
        break;
      }
      case '<': {
        bool two = _match('=');
        _addToken(two ? TokenType.LESS_EQUAL: TokenType.LESS, two ? '<=' : char);
        break;
      }
      case '>': {
        bool two = _match('=');
        _addToken(two ? TokenType.GREATER_EQUAL : TokenType.GREATER, two ? '>=' : char);
        break;
      }
      case '&': {
        if (_match('&')) _addToken(TokenType.AMP_AMP, '&&');
        break;
      }
      case '|': {
        if (_match('|')) _addToken(TokenType.PIPE_PIPE, '||');
        break;
      }
      case '"': _getString(); break;
      case ' ':
      case '\t':
      case '\r':
      case '\b':
        break;
      case '\n': 
        line++;
        break;
      default: {
        if (_isDigit(char)) {
          _getNumber(char);
          break;
        } else if (_isAlpha(char)) {
          _getIdentifier();
          break;
        }
        
        ErrorReporter.report(new SyntaxError(line, "Unknown token '$char'."));
      }
    }
  }

  void _matchMultilineComment() {
    while (!isAtEnd() && _peek() != '*') {
      if (_peek() == '\n') line++;
      _advance();
    }
    
    if (isAtEnd()) throw new SyntaxError(line, 'Unterminated multi line comments section.');

    _advance();
    if (_peek() == '/') {
      _advance();
      return;
    }

    _matchMultilineComment();
  }

  void _getIdentifier() {
    while (_isAlphaNum(_peek())) _advance();

    String id = source.substring(start, offset);
    TokenType type = _keywords[id];

    _addToken(type ?? TokenType.IDENTIFIER, id);
    return;
  }

  void _getNumber(String first) {
    String number = '';
    number += first;
    
    // Parse an hexadecimal constant
    if (first == '0' && (_peek().toLowerCase() == 'x')) {
      number += _advance();
      while (!isAtEnd() && _isHexDigit(_peek())) {
        number += _advance();
      }

      _addToken(TokenType.INTEGER, int.parse(number));
      return;
    }

    while (_isDigit(_peek()) && !isAtEnd()) number += _advance();

    // If there is not a leading '.' it's an integer constant
    if (_peek() != '.') {
      _addToken(TokenType.INTEGER, int.parse(number));
      return;
    }
    
    // Parse decimal constant
    number += _advance();
    while (_isDigit(_peek())) {
      number += _advance();
    }

    if (number.endsWith('.')) number += '0';

    if (_peek().toLowerCase() == 'e') {
      number += _advance();
      if (_peek() == '+' || _peek() == '-') number += _advance();
      
      if (!_isDigit(_peek())) {
        number += '0';
      } else {
        while (_isDigit(_peek())) {
          number += _advance();
        }
      }
    }

    _addToken(TokenType.DOUBLE, double.parse(number));
  }

  void _getString() {
    StringBuffer string = new StringBuffer();
    while (_peek() != '\n' && _peek() != '"' && !isAtEnd()) {
      if (_peek() == '\\' && _escapers.contains(_peekNext())) {
        _advance();
        String char;
        switch (_advance()) {
          case 'n': char = '\n'; break;
          case 't': char = '\t'; break;
          case 'b': char = '\b'; break;
          case 'r': char = '\r'; break;
          case '\\': char = '\\'; break;
          case '"': char = '"'; break;
        }
        string.write(char);
      } else {
        string.write(_advance());
      }
    }

    if (isAtEnd() || _peek() == '\n') throw new SyntaxError(line, 'Unterminated string.');
    // Consume '"'
    _advance();

    _addToken(TokenType.STRING, string.toString());
  }

  void _addToken(TokenType type, Object value) {
    tokens.add(new Token(type, source.substring(start, offset), value, line));
  }

  bool _match(String char) {
    if (isAtEnd()) return false;

    if (_peek() == char) {
      _advance();
      return true;
    }

    return false;
  }

  String _peek() {
    return isAtEnd() ? '' : source[offset];
  }

  String _peekNext() {
    return isAtEnd() ? '' : source[offset + 1];
  }

  String _advance() {
    offset++;
    return source[offset - 1];
  }

  bool isAtEnd() {
    return offset >= source.length;
  }

  bool _isDigit(String char) {
    return new RegExp('[0-9]').hasMatch(char);
  }

  bool _isHexDigit(String char) {
    return new RegExp('[0-9a-fA-F]').hasMatch(char);
  }

  bool _isAlpha(String char) {
    return new RegExp('[a-zA-Z_]').hasMatch(char);
  }

  bool _isAlphaNum(String char) {
    return _isAlpha(char) || _isDigit(char);
  }
}