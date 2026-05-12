import cpp

/**
 * A predicate that holds if `cond` is an expression that checks that `memberAddr` is non-null.
 * `memberAddr` is an address-of-member expression.
 */
predicate isNonNullCondition(Expr cond, Expr memberAddr) {
  // Form: memberAddr != 0
  exists(NEExpr ne |
    cond = ne and
    ne.getLeftOperand() = memberAddr and
    ne.getRightOperand().(Literal).getValue() = "0"
  )
  or
  // Form: !(memberAddr == 0)
  exists(NotExpr ne, EQExpr eq |
    cond = ne and
    ne.getOperand() = eq and
    eq.getLeftOperand() = memberAddr and
    eq.getRightOperand().(Literal).getValue() = "0"
  )
  or
  // Form: implicit boolean conversion on memberAddr (e.g., if(&ptr->member))
  cond = memberAddr
}

/**
 * A class representing an expression that takes the address of a struct member.
 */
class MemberAddressExpression extends Expr {
  FieldAccess fa;

  MemberAddressExpression() {
    this.(AddressOfExpr).getOperand() = fa
  }

  /** Gets the field access inside the address expression. */
  FieldAccess getFieldAccess() { result = fa }
}

/**
 * A loop whose condition contains a non-null check on a struct member address,
 * where the member offset is greater than 0.
 */
class VulnerableLoop extends Loop {
  MemberAddressExpression memberAddr;

  VulnerableLoop() {
    exists(Expr cond, FieldAccess fa |
      cond = this.getCondition() and
      isNonNullCondition(cond, memberAddr) and
      fa = memberAddr.getFieldAccess() and
      fa.getTarget().getByteOffset() > 0
    )
  }

  /** Gets the member address expression involved in the condition. */
  MemberAddressExpression getMemberAddress() { result = memberAddr }
}
