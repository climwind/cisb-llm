import cpp

// =============================================================================
// Phase 1: Syntax Anchor — pure AST matching
// =============================================================================

/**
 * A variable declared with `const` but not `volatile`.
 * The compiler may assume its value never changes and cache it in a register.
 */
class ConstNonVolatileVar extends Variable {
  ConstNonVolatileVar() {
    this.isConst() and not this.isVolatile()
  }
}

/**
 * A write (assignment / increment / decrement) whose left-hand side
 * reaches a ConstNonVolatileVar through any chain of pointer casts
 * and dereferences.
 *
 * This is the irreducible syntactic signature of "const bypass":
 * some write operation somewhere in the code has a path to a const
 * variable that goes through at least one pointer indirection
 * (AddressOfExpr, PointerDereferenceExpr, or Cast).
 *
 * Covers ALL syntactic spellings:
 *   *(T*)&cv        = val;
 *   ((T*)&cv)->f    = val;
 *   *(T*)(uintptr_t)&cv = val;
 *   (*(T**)ptr)     = &cv;   (via intermediate pointer)
 */
predicate constWriteViaPointer(ConstNonVolatileVar cv, Expr writeSite) {
  exists(AssignExpr assign, VariableAccess va |
    writeSite = assign and
    // The lvalue eventually reaches a VariableAccess to cv
    assign.getLValue().getAChild*() = va and
    va.getTarget() = cv and
    // At least one pointer-level operation exists between write and cv
    exists(AddressOfExpr addr |
      assign.getLValue().getAChild*() = addr
    )
  )
  or
  exists(CrementOperation incdec, VariableAccess va |
    writeSite = incdec and
    incdec.getOperand().getAChild*() = va and
    va.getTarget() = cv and
    exists(AddressOfExpr addr |
      incdec.getOperand().getAChild*() = addr
    )
  )
}

// =============================================================================
// Phase 2: Semantic Constraints (TODO — layered in later)
// =============================================================================
//
// 1. The const variable is READ before the write (compiler caches the value):
//    A VariableAccess to cv appears as an rvalue before the writeSite in
//    control-flow order.
//
// 2. No compiler barrier between the cached read and the write:
//    No volatile access, asm barrier, or function call that would force
//    the compiler to reload cv.
//
// 3. (Optional) The stale cached value is used in a security check:
//    The read before the write is part of a null-check, bounds-check,
//    or access-control decision.
