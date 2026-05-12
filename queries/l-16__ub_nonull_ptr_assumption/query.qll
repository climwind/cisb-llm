/**
 * Provides predicates and classes for detecting CISB related to GCC inline assembly
 * memory operands causing null check elimination.
 */

import cpp
import semmle.code.cpp.controlflow.Dominance

/**
 * Holds if `expr` is a dereference of pointer variable `v`, accounting for casts and field access.
 */
predicate pointerDerefOf(Expr expr, Variable v) {
  exists(DereferenceExpr deref |
    deref = expr.getAChild*()
  |
    deref.getOperand().getAChild*() = any(VariableAccess va | va.getTarget() = v)
  )
  or
  exists(FieldAccess fa |
    fa = expr.getAChild*()
  |
    fa.getQualifier().getAChild*() = any(VariableAccess va | va.getTarget() = v)
  )
  or
  exists(AddressOfExpr addr |
    addr = expr.getAChild*()
  |
    addr.getOperand().getAChild*() = any(VariableAccess va | va.getTarget() = v)
  )
}

/**
 * Holds if `asm` is an inline assembly statement that has a memory operand
 * (constraint containing 'm') whose expression dereferences variable `v`.
 */
predicate asmMemoryDerefOperand(AsmStmt asm, Variable v) {
  exists(AsmOperand operand | operand = asm.getAnOperand() |
    (operand.getConstraint().matches("=*m*") or operand.getConstraint().matches("*m*")) and
    pointerDerefOf(operand.getExpression(), v)
  )
}

/**
 * A null check expression on a pointer variable.
 */
class NullCheckExpr extends Expr {
  Variable checkedVar;

  NullCheckExpr() {
    exists(Variable v |
      checkedVar = v and
      (
        // v == NULL or v == 0
        exists(EQExpr eq | eq = this and
          (eq.getLeftOperand().getAChild*() = any(VariableAccess va | va.getTarget() = v) and
           (eq.getRightOperand().getValue().toInt() = 0 or eq.getRightOperand().getValue().toInt() = -1))
          or
          (eq.getRightOperand().getAChild*() = any(VariableAccess va | va.getTarget() = v) and
           (eq.getLeftOperand().getValue().toInt() = 0 or eq.getLeftOperand().getValue().toInt() = -1))
        )
        or
        // v != NULL or v != 0
        exists(NEExpr ne | ne = this and
          (ne.getLeftOperand().getAChild*() = any(VariableAccess va | va.getTarget() = v) and
           (ne.getRightOperand().getValue().toInt() = 0 or ne.getRightOperand().getValue().toInt() = -1))
          or
          (ne.getRightOperand().getAChild*() = any(VariableAccess va | va.getTarget() = v) and
           (ne.getLeftOperand().getValue().toInt() = 0 or ne.getLeftOperand().getValue().toInt() = -1))
        )
        or
        // !v
        exists(NotExpr not | not = this and not.getOperand().getAChild*() = any(VariableAccess va | va.getTarget() = v))
        or
        // if(v) - implicit conversion to bool
        exists(ImplicitConversion conv | conv = this and conv.getExpr().getAChild*() = any(VariableAccess va | va.getTarget() = v) and
          conv.getType() instanceof BoolType)
      )
    )
  }

  Variable getCheckedVariable() { result = checkedVar }
}

/**
 * Holds if the inline assembly statement `asm` precedes the null check `check` in the same function,
 * and the asm dominates the null check in the control flow graph.
 */
predicate asmDominatesNullCheck(AsmStmt asm, NullCheckExpr check) {
  asm.getFunction() = check.getFunction() and
  asm.getLocation() < check.getLocation() and
  dominates(asm, check)
}
