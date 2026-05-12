import cpp

/**
 * A write operation that modifies a const variable through pointer indirection.
 */
class ConstVarModification extends Expr {
  Variable v;

  ConstVarModification() {
    exists(AssignExpr ae, VariableAccess va, AddressOfExpr aoe |
      ae.getLValue() = this and
      this.getAChild*() = va and
      va.getTarget() = v and
      this.getAChild*() = aoe and
      aoe.getOperand().getAChild*() = va
    ) and
    v.isConst() and
    not v.isVolatile()
  }

  Variable getModifiedVar() { result = v }
}
