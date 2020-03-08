import '../lexer/tokens.dart';
import '../types/type.dart';

abstract class Expr {
  Type type;
  Object accept(ExprVisitor visitor);
}

class LiteralExpr implements Expr {
  Object value;
  LiteralExpr(this.type, this.value);

  @override
  Object accept(ExprVisitor visitor) {
    return visitor.visitLiteralExpr(this);
  }

  @override
  Type type;
}

class VariableExpr implements Expr {
  Token name;

  VariableExpr(this.name);

  @override
  Object accept(ExprVisitor visitor) {
    return visitor.visitVariableExpr(this);
  }

  @override
  Type type;
}

class ArrayExpr implements Expr {
  @override
  Type type;
  Token keyword;
  Expr size;

  ArrayExpr(this.keyword, this.type, this.size);

  @override
  Object accept(ExprVisitor visitor) {
    return visitor.visitArrayExpr(this);
  }

}

class IndexExpr implements Expr {
  @override
  Type type;
  Token bracket;
  Expr owner;
  Expr index;

  IndexExpr(this.bracket, this.owner, this.index);

  @override
  Object accept(ExprVisitor visitor) {
    return visitor.visitIndexExpr(this);
  }
  
}

class AccessExpr implements Expr {
  @override
  Type type;
  Token dot;
  Expr target;
  Expr field;

  AccessExpr(this.dot, this.target, this.field);

  @override
  Object accept(ExprVisitor visitor) {
    return visitor.visitAccessExpr(this);
  }

}

class ThisExpr implements Expr {
  @override
  Type type;
  Token keyword;

  ThisExpr(this.keyword);

  @override
  Object accept(ExprVisitor visitor) {
    return visitor.visitThisExpr(this);
  }
  
}

class GroupingExpr implements Expr {
  Expr expression;

  GroupingExpr(this.expression);

  @override
  Object accept(ExprVisitor visitor) {
    return visitor.visitGroupingExpr(this);
  }

  @override
  Type type;
}

class UnaryExpr implements Expr {
  Token op;
  Expr expression;

  UnaryExpr(this.op, this.expression);

  @override
  Object accept(ExprVisitor visitor) {
    return visitor.visitUnaryExpr(this);
  }

  @override
  Type type;
}

class BinaryExpr implements Expr {
  Token op;
  Expr left;
  Expr right;

  BinaryExpr(this.op, this.left, this.right);

  @override
  Object accept(ExprVisitor visitor) {
    return visitor.visitBinaryExpr(this);
  }

  @override
  Type type;
}

class LogicalExpr implements Expr {
  Token op;
  Expr left;
  Expr right;

  LogicalExpr(this.op, this.left, this.right);

  @override
  Object accept(ExprVisitor visitor) {
    return visitor.visitLogicalExpr(this);
  }

  @override
  Type type;
}

class AssignExpr implements Expr {
  Token op;
  Expr target;
  Expr value;

  AssignExpr(this.op, this.target, this.value);

  @override
  Object accept(ExprVisitor visitor) {
    return visitor.visitAssignExpr(this);
  }

  @override
  Type type;
}

class CallExpr implements Expr {
  Token paren;
  Expr callee;
  List<Expr> arguments;

  CallExpr(this.paren, this.callee, this.arguments);

  @override
  Object accept(ExprVisitor visitor) {
    return visitor.visitCallExpr(this);
  }

  @override
  Type type;
}


abstract class ExprVisitor {

  visitAccessExpr(AccessExpr expr) {
    return expr.accept(this);
  }

  visitArrayExpr(ArrayExpr expr) {
    return expr.accept(this);
  }

	visitAssignExpr(AssignExpr expr) {
		return expr.accept(this);
	}

	visitBinaryExpr(BinaryExpr expr) {
		return expr.accept(this);
	}

	visitCallExpr(CallExpr expr) {
		return expr.accept(this);
	}

	visitGroupingExpr(GroupingExpr expr) {
		return expr.accept(this);
	}

  visitIndexExpr(IndexExpr expr) {
    return expr.accept(this);
  }

	visitLiteralExpr(LiteralExpr expr) {
		return expr.accept(this);
	}

	visitLogicalExpr(LogicalExpr expr) {
		return expr.accept(this);
	}

  visitThisExpr(ThisExpr expr) {
    return expr.accept(this);
  }

	visitUnaryExpr(UnaryExpr expr) {
		return expr.accept(this);
	}

	visitVariableExpr(VariableExpr expr) {
		return expr.accept(this);
	}

}