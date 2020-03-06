class Precedence {
  static int NONE = 0;
  static int ASSIGNMENT = 1;
  static int OR = 2;
  static int AND = 4;
  static int EQUALITY = 8;
  static int COMPARISON = 16;
  static int SUM = 32;
  static int PRODUCT = 64;
  static int UNARY = 128;
  static int CALL = 256;
}

class ParseRule {
  int precedence;
  Function prefix;
  Function postfix;
}

class PrefixRule extends ParseRule {
  int precedence;
  Function prefix;

  PrefixRule(this.precedence, this.prefix);
}

class InfixRule extends ParseRule {
  int precedence;
  Function prefix;
  Function postfix;

  InfixRule(this.precedence, [this.prefix, this.postfix]);
}
