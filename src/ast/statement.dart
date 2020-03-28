import '../lexer/tokens.dart';
import '../types/type.dart';
import 'expression.dart';

abstract class Stmt {
  Object accept(StmtVisitor visitor);
}

abstract class DeclStmt {
  Token name;
}

class VarStmt implements Stmt, DeclStmt {
  Type type;
  Token name;
  Expr initializer;

  VarStmt(this.type, this.name, this.initializer);

  @override
  void accept(StmtVisitor visitor) {
    visitor.visitVarStmt(this);
  }
}

class ExpressionStmt implements Stmt {
  Expr expression;

  ExpressionStmt(Expr expr): expression = expr;

  @override
  void accept(StmtVisitor visitor) {
    visitor.visitExpressionStmt(this);
  }
}

class BlockStmt implements Stmt {
  List<Stmt> statements;

  BlockStmt(this.statements);

  @override
  void accept(StmtVisitor visitor) {
    visitor.visitBlockStmt(this);
  }
}

class IfStmt implements Stmt {
  Token keyword;
  Expr condition;
  Stmt thenStmt;
  Stmt elseStmt;

  IfStmt(this.keyword, this.condition, this.thenStmt, this.elseStmt);

  @override
  void accept(StmtVisitor visitor) {
    visitor.visitIfStmt(this);
  }
}

class WhileStmt implements Stmt {
  Token keyword;
  Expr condition;
  Stmt body;

  WhileStmt(this.keyword, this.condition, this.body);

  @override
  void accept(StmtVisitor visitor) {
    visitor.visitWhileStmt(this);
  }
}

class PrintStmt implements Stmt {
  Token keyword;
  List<Expr> expressions;

  PrintStmt(this.keyword, this.expressions);

  @override
  void accept(StmtVisitor visitor) {
    visitor.visitPrintStmt(this);
  }
  
}

class ForStmt implements Stmt {
  Token keyword;
  Expr initializer;
  Expr condition;
  Expr incrementer;
  Stmt body;

  ForStmt(this.keyword, this.initializer, this.condition, this.incrementer, this.body);

  @override
  void accept(StmtVisitor visitor) {
    visitor.visitForStmt(this);
  }
}

class BreakStmt implements Stmt {
  Token keyword;

  BreakStmt(this.keyword);

  @override
  void accept(StmtVisitor visitor) {
    return visitor.visitBreakStmt(this);
  }
}

class ReturnStmt implements Stmt {
  Token keyword;
  Expr value;
  Type expectedType;

  ReturnStmt(this.keyword, this.value);

  @override
  void accept(StmtVisitor visitor) {
    return visitor.visitReturnStmt(this);
  }
}

class FunctionStmt implements Stmt, DeclStmt {
  Token name;
  Type returnType;
  List<VarStmt> params;
  BlockStmt body;
  bool isConstruct;

  FunctionStmt(this.name, this.params, this.returnType, this.body, this.isConstruct);

  @override
  void accept(StmtVisitor visitor) {
    visitor.visitFunctionStmt(this);
  }
}

class ClassStmt implements Stmt, DeclStmt {
  Token name;
  Token parent;
  List<VarStmt> fields;
  List<FunctionStmt> methods;

  ClassStmt(this.name, this.parent, this.fields, this.methods);
  
  @override
  void accept(StmtVisitor visitor) {
    visitor.visitClassStmt(this);
  }

}

abstract class StmtVisitor {

	visitBlockStmt(BlockStmt stmt) {
		return stmt.accept(this);
	}

  visitClassStmt(ClassStmt stmt) {
    return stmt.accept(this);
  }

	visitExpressionStmt(ExpressionStmt stmt) {
		return stmt.accept(this);
	}

	visitFunctionStmt(FunctionStmt stmt) {
		return stmt.accept(this);
	}

	visitIfStmt(IfStmt stmt) {
		return stmt.accept(this);
	}

	visitVarStmt(VarStmt stmt) {
		return stmt.accept(this);
	}

	visitWhileStmt(WhileStmt stmt) {
		return stmt.accept(this);
	}

  visitForStmt(ForStmt stmt) {
    return stmt.accept(this);
  }

  visitPrintStmt(PrintStmt stmt) {
    return stmt.accept(this);
  }

  visitReturnStmt(ReturnStmt stmt) {
    return stmt.accept(this);
  }

  visitBreakStmt(BreakStmt stmt) {
    return stmt.accept(this);
  }
}