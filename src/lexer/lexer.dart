import '../error/error.dart';
import 'tokens.dart';

class Lexer {
  final String source;
  int line = 1;
  int offset = 0;
  int start = 0;
  List<Token> tokens = [];
  
  //List<String> _escapers = ['n', 't', 'b', 'r', '\\', '"'];
  
  Map<String, TokenType> _keywords = {
    "int": TokenType.KW_INT,
    "double": TokenType.KW_DOUBLE,
    "string": TokenType.KW_STRING,
    "bool": TokenType.KW_BOOL,
    "void": TokenType.KW_VOID,
    "true": TokenType.TRUE,
    "false": TokenType.FALSE,
    "class": TokenType.CLASS,
    "interface": TokenType.INTERFACE,
    "null": TokenType.NULL,
    "this": TokenType.THIS,
    "extends": TokenType.EXTENDS,
    "implements": TokenType.IMPLEMENTS,
    "for": TokenType.FOR,
    "while": TokenType.WHILE,
    "if": TokenType.IF,
    "else": TokenType.ELSE,
    "return": TokenType.RETURN,
    "break": TokenType.BREAK,
    "new": TokenType.NEW,
    "array": TokenType.ARRAY,
    "print": TokenType.PRINT,
    "readInt": TokenType.RD_INT,
    "readLine": TokenType.RD_LINE,
  };

  Lexer(this.source);

  List<Token> tokenize() {
    while (!isAtEnd()) {
      start = offset;
      Token token = getToken();
      if (token.type != TokenType.WHITESPACE) tokens.add(token);
    }

    tokens.add(new Token(TokenType.EOF, 'EOF', null, line));
    return tokens;
  }

  Token getToken() {
    String char = _advance();

    switch (char) {
      case '(': return _makeToken(TokenType.LEFT_PAREN, char);
      case ')': return _makeToken(TokenType.RIGHT_PAREN, char);
      case '{': return _makeToken(TokenType.LEFT_BRACE, char);
      case '}': return _makeToken(TokenType.RIGHT_BRACE, char);
      case ',': return _makeToken(TokenType.COMMA, char);
      case '.': return _makeToken(TokenType.DOT, char);
      case ';': return _makeToken(TokenType.SEMICOLON, char);
      case '+': return _makeToken(TokenType.PLUS, char);
      case '-': return _makeToken(TokenType.MINUS, char);
      case '*': return _makeToken(TokenType.STAR, char);
      case '%': return _makeToken(TokenType.PERCENT, char);
      case '/': {
        if (_peek() == '/') {
          while (_peek() != '\n' && !isAtEnd()) _advance();
          return _makeToken(TokenType.WHITESPACE, '');
        }

        if (_peek() == "*") {
          _advance();
          _matchMultilineComment();
          return _makeToken(TokenType.WHITESPACE, '');
        }

        return _makeToken(TokenType.SLASH, char);
      }
      case '!': {
        bool two = _match('=');
        return _makeToken(two ? TokenType.BANG_EQUAL : TokenType.BANG, two ? '!=' : char);
      }
      case '=': {
        bool two = _match('=');
        return _makeToken(two ? TokenType.EQUAL_EQUAL : TokenType.EQUAL, two ? '==' : char);
      }
      case '<': {
        bool two = _match('=');
        return _makeToken(two ? TokenType.LESS_EQUAL: TokenType.LESS, two ? '<=' : char);
      }
      case '>': {
        bool two = _match('=');
        return _makeToken(two ? TokenType.GREATER_EQUAL : TokenType.GREATER, two ? '>=' : char);
      }
      case '&': {
        if (_match('&')) return _makeToken(TokenType.AMP_AMP, '&&');
        break;
      }
      case '|': {
        if (_match('|')) return _makeToken(TokenType.PIPE_PIPE, '||');
        break;
      }
      case '"': return _getString();
      case ' ':
      case '\t':
      case '\r':
      case '\b':
        return _makeToken(TokenType.WHITESPACE, char);
      case '\n': line++;
        return _makeToken(TokenType.WHITESPACE, char);
      default: {
        if (_isDigit(char)) return _getNumber(char);
        if (_isAlpha(char)) return _getIdentifier();
        break;
      }
    }

    throw new SyntaxError(line, "Unknown token '$char'.");
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

  Token _getIdentifier() {
    while (_isAlphaNum(_peek())) _advance();

    String id = source.substring(start, offset);
    TokenType type = _keywords[id];

    return _makeToken(type ?? TokenType.IDENTIFIER, id);
  }

  Token _getNumber(String first) {
    String number = '';
    number += first;
    
    // Parse an hexadecimal constant
    if (first == '0' && (_peek().toLowerCase() == 'x')) {
      number += _advance();
      while (!isAtEnd() && _isHexDigit(_peek())) {
        number += _advance();
      }

      return _makeToken(TokenType.INTEGER, int.parse(number));
    }

    while (_isDigit(_peek()) && !isAtEnd()) number += _advance();

    // If there is not a leading '.' it's an integer constant
    if (_peek() != '.') return _makeToken(TokenType.INTEGER, int.parse(number));
    
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

    return _makeToken(TokenType.DOUBLE, double.parse(number));
  }

  Token _getString() {
    String string = "";
    while (_peek() != '\n' && _peek() != '"' && !isAtEnd()) {
      string += _peek();
      _advance();
    }

    if (isAtEnd() || _peek() == '\n') throw new SyntaxError(line, 'Unterminated string.');
    // Consume '"'
    _advance();

    return _makeToken(TokenType.STRING, string);
  }

  Token _makeToken(TokenType type, Object value) {
    return new Token(type, source.substring(start, offset), value, line);
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
    return new RegExp('[a-zA-Z]').hasMatch(char);
  }

  bool _isAlphaNum(String char) {
    return char == '_' || _isAlpha(char) || _isDigit(char);
  }
}