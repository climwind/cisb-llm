import cpp

// =============================================================================
// Phase 1: Syntax Anchor — pure AST matching
// =============================================================================

/**
 * A call to a memory-clearing function.
 *
 * Covers library names AND compiler builtin names because CodeQL C/C++
 * extraction may resolve `memset()` from <string.h> as __builtin_memset
 * or similar, and `hasName` does not always match across builtin aliases.
 */
class MemClearCall extends FunctionCall {
  MemClearCall() {
    this.getTarget().hasName("memset") or
    this.getTarget().hasName("bzero") or
    this.getTarget().hasName("explicit_bzero") or
    this.getTarget().hasName("__builtin_memset") or
    this.getTarget().hasName("__memset") or
    this.getTarget().hasName("__aeabi_memclr") or
    this.getTarget().getName().matches("%memset") or
    this.getTarget().getName().matches("%bzero")
  }

  /** The memory buffer expression (first argument). */
  Expr getBuffer() { result = this.getArgument(0) }

  /**
   * Resolves the buffer to the underlying Variable, if any.
   * Handles:
   *   memset(ptr, ...)          — direct VariableAccess
   *   memset(&obj, ...)         — AddressOfExpr wrapping VariableAccess
   *   memset(arr, ...)          — array → pointer decay
   */
  Variable getBufferVariable() {
    exists(Expr buf |
      buf = this.getBuffer().getUnconverted() and
      (
        result = buf.(VariableAccess).getTarget()
        or
        result = buf.(AddressOfExpr).getOperand().getUnconverted().(VariableAccess).getTarget()
      )
    )
  }
}

/**
 * A call to a memory-releasing function.
 */
class MemReleaseCall extends FunctionCall {
  MemReleaseCall() {
    this.getTarget().hasName("free") or
    this.getTarget().hasName("kfree") or
    this.getTarget().hasName("vfree") or
    this.getTarget().hasName("__builtin_free") or
    this.getTarget().getName().matches("%free")
  }

  Expr getBuffer() { result = this.getArgument(0) }
}

// =============================================================================
// Phase 2: Semantic Constraints (TODO — layered in later)
// =============================================================================
//
// After Phase 1 confirms the AST shape matches, layer on:
//
// 1. Same-object link:
//    MemClearCall.getBufferVariable() = MemReleaseCall's buffer variable
//    (or same memory object via data flow)
//
// 2. No-read-between:
//    Between the clear and the release, no VariableAccess to the same
//    variable appears as an rvalue (except inside MemReleaseCall).
//
// 3. (Optional) Sensitive data:
//    The buffer variable is tainted with sensitive data.
