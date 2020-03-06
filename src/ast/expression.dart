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

class TernaryExpr implements Expr {
  Token op;
  Expr cond;
  Expr thenExpr;
  Expr elseExpr;

  TernaryExpr(this.op, this.cond, this.thenExpr, this.elseExpr);

  @override
  Object accept(ExprVisitor visitor) {
    return visitor.visitTernaryExpr(this);
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

	visitAssignExpr(AssignExpr expr) {
		return expr.accept(this);
	}

	visitTernaryExpr(TernaryExpr expr) {
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

	visitLiteralExpr(LiteralExpr expr) {
		return expr.accept(this);
	}

	visitLogicalExpr(LogicalExpr expr) {
		return expr.accept(this);
	}

	visitUnaryExpr(UnaryExpr expr) {
		return expr.accept(this);
	}

	visitVariableExpr(VariableExpr expr) {
		return expr.accept(this);
	}

}