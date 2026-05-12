import cpp

/** A variable declared with const and without volatile. */
predicate isConstWithoutVolatile(VariableDecl v) {
  v.getType().hasConstQualifier() and
  not v.getType().hasVolatileQualifier()
}

/** Holds if expression `e` is an address-of of variable `v` followed by zero or more casts. */
predicate addressesVar(Expr e, VariableDecl v) {
  exists(AddressOfExpr aoe | aoe.getOperand() = v.getAnAccess() and e = aoe)
  or
  exists(CastExpr ce, Expr sub | ce = e and addressesVar(sub, v))
}

/** Holds if expression `target` is a write target (LHS of assignment or first argument of memory copy). */
predicate isWriteTarget(Expr target) {
  exists(AssignExpr ae | ae.getLValue() = target)
  or
  exists(FunctionCall fc |
    fc.getTarget().hasName("memcpy") or fc.getTarget().hasName("__builtin_memcpy") or fc.getTarget().getName().matches("%memcpy") or
    fc.getTarget().hasName("memmove") or fc.getTarget().hasName("__builtin_memmove") or fc.getTarget().getName().matches("%memmove") or
    fc.getTarget().hasName("memset") or fc.getTarget().hasName("__builtin_memset") or fc.getTarget().getName().matches("%memset") or
    fc.getTarget().hasName("strcpy") or fc.getTarget().hasName("__builtin_strcpy") or fc.getTarget().getName().matches("%strcpy") or
    fc.getTarget().hasName("strncpy") or fc.getTarget().hasName("__builtin_strncpy") or fc.getTarget().getName().matches("%strncpy")
  ) and
  fc.getArgument(0) = target
}

/** A write operation that modifies a const variable through a pointer cast. */
class ConstVarModification extends Expr {
  VariableDecl v;

  ConstVarModification() {
    isWriteTarget(this) and
    exists(Expr addr | addressesVar(addr, v) and exists(CastExpr ce | ce = this.getAChild*() and ce.getTargetType().hasConstQualifier())) and
    isConstWithoutVolatile(v)
  }

  /** Gets the const variable being modified. */
  VariableDecl getModifiedVar() { result = v }
}
