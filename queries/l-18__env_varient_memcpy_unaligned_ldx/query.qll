import cpp

/** A standard memory function that the compiler recognizes as a builtin. */
class BuiltinMemoryFunction extends Function {
  BuiltinMemoryFunction() {
    hasName("memset") or
    hasName("__builtin_memset") or
    hasName("memcpy") or
    hasName("__builtin_memcpy")
  }
}

/** Holds if the function `f` is an IO memory access wrapper. */
predicate isIOAccessorFunction(Function f) {
  f.getName().matches("%_io") or
  f.getName() = "memset_io" or
  f.getName() = "memcpy_fromio" or
  f.getName() = "memcpy_toio"
}

/** A call to a builtin memory function inside an IO accessor. */
class VulnerableCallToBuiltinInIOAccessor extends FunctionCall {
  VulnerableCallToBuiltinInIOAccessor() {
    exists(Function target, Function enclosing |
      this.getTarget() = target and
      target instanceof BuiltinMemoryFunction and
      this.getEnclosingFunction() = enclosing and
      isIOAccessorFunction(enclosing)
    )
  }
}

/** Holds if the function `f` contains no volatile asm statement that would block bulk optimization. */
predicate hasNoVolatileAsmBarrier(Function f) {
  not exists(AsmStmt asm |
    asm.getEnclosingFunction() = f and
    none() /* Phase 2: volatile asm check */
  )
}
