import cpp

// =============================================================================
// Phase 1: Syntax Anchor — pure AST matching
// =============================================================================

/**
 * An address-of expression whose operand is a field access.
 * Matches: &ptr->field, &((T*)ptr)->field, &(*ptr).field, &obj.field
 */
class MemberAddressExpr extends AddressOfExpr {
  MemberAddressExpr() {
    this.getOperand() instanceof FieldAccess
  }

  FieldAccess getFieldAccess() {
    result = this.getOperand()
  }

  Field getField() { result = this.getFieldAccess().getTarget() }

  Expr getBase() { result = this.getFieldAccess().getQualifier() }
}

/**
 * A null-like literal: 0, NULL, nullptr, or any expression of null pointer type.
 */
private predicate isNullLike(Expr e) {
  e.getValueText() = "0" or
  e.getValueText() = "NULL" or
  e instanceof NullPointerType  // C++ nullptr
}

/**
 * A null-check that involves a MemberAddressExpr.
 *
 * Covers ALL syntactic forms (from equivalence_notes):
 *   Form A: &ptr->field == NULL       → EQExpr(MemberAddressExpr, null)
 *   Form B: &ptr->field != NULL       → NEExpr(MemberAddressExpr, null)
 *   Form C: !&ptr->field              → NotExpr(MemberAddressExpr)
 *   Form D: !(&ptr->field == NULL)    → NotExpr(EQExpr(MemberAddressExpr, null))
 *   Form E: &ptr->field as condition  → MemberAddressExpr used as branch cond
 */
class MemberAddressNullCheck extends Expr {
  MemberAddressNullCheck() {
    exists(MemberAddressExpr mae |
      // Form A: &ptr->field == NULL / == 0
      (this instanceof EQExpr and
       this.(EQExpr).hasOperands(mae, any(Expr other | isNullLike(other))))
      or
      // Form B: &ptr->field != NULL / != 0
      (this instanceof NEExpr and
       this.(NEExpr).hasOperands(mae, any(Expr other | isNullLike(other))))
      or
      // Form C: !&ptr->field
      (this instanceof NotExpr and
       this.(NotExpr).getOperand() = mae)
      or
      // Form D: !(&ptr->field == NULL)
      (this instanceof NotExpr and
       this.(NotExpr).getOperand() instanceof EQExpr and
       this.(NotExpr).getOperand().(EQExpr).hasOperands(mae, any(Expr other | isNullLike(other))))
      or
      // Form E: &ptr->field used directly as a condition (implicit != 0)
      // (this = mae when mae is not part of any comparison)
      (this = mae and
       not this instanceof ComparisonOperation and
       not this.getParent*() instanceof ComparisonOperation and
       not this.getParent*() instanceof NotExpr)
    )
  }
}

// =============================================================================
// Phase 2: Semantic Constraints (TODO — layered in later)
// =============================================================================
//
// 1. The field has a positive byte offset from the struct base:
//    f.getByteOffset() > 0
//    (This is what makes the null check "provably always true/false")
//
// 2. The pointer base comes from an external source (parameter, global,
//    or function return) — not a stack variable with known address.
//
// 3. The null check guards a security-relevant operation (memory access,
//    privileged operation, bounds check, etc.).
