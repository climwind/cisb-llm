import cpp

/**
 * A function that is expected to return its first argument (e.g., memset, memcpy).
 */
class MemOpFunction extends Function {
  MemOpFunction() {
    exists(string name | name = this.getName() |
      name = "memset" or
      name = "__builtin_memset" or
      name = "memcpy" or
      name = "__builtin_memcpy" or
      name = "strcpy" or
      name = "__builtin_strcpy" or
      name.matches("%memset") or
      name.matches("%memcpy") or
      name.matches("%strcpy")
    )
    and
    exists(Parameter p | p = this.getAParameter() | p.getIndex() = 0)  // has at least one parameter
    and
    this.getReturnType() instanceof VoidType = false  // not void
  }

  /**
   * Gets the first parameter of this function.
   */
  Parameter getFirstParam() {
    result = this.getParameter(0)
  }
}

/**
 * Holds if the function `f` has a direct return of its first parameter on all return paths.
 */
predicate returnsFirstParamDirectly(MemOpFunction f) {
  exists(ReturnStmt rs | rs.getEnclosingFunction() = f |
    exists(VariableAccess va | va = rs.getExpr() |
      va.getTarget() = f.getFirstParam()
    )
  ) and
  not exists(ReturnStmt rs2 | rs2.getEnclosingFunction() = f |
    not (exists(VariableAccess va2 | va2 = rs2.getExpr() |
      va2.getTarget() = f.getFirstParam()
    ))
  )
}

/**
 * Holds if the first parameter of `f` is assigned to anywhere in the function body.
 */
predicate firstParamModified(MemOpFunction f) {
  exists(AssignExpr a |
    a.getLValue() instanceof VariableAccess and
    a.getLValue().(VariableAccess).getTarget() = f.getFirstParam() and
    a.getEnclosingFunction() = f
  )
}

/**
 * A candidate query result for return register mismatch.
 */
class ReturnRegisterMismatch extends MemOpFunction {
  ReturnRegisterMismatch() {
    not returnsFirstParamDirectly(this) and
    exists(ReturnStmt rs | rs.getEnclosingFunction() = this |
      not exists(VariableAccess va | va = rs.getExpr() |
        va.getTarget() = this.getFirstParam()
      )
      or
      (exists(VariableAccess va | va = rs.getExpr() |
        va.getTarget() = this.getFirstParam()
      ) and
      firstParamModified(this))
    )
  }

  string toString() {
    result = this.getName() + " does not return first argument directly."
  }
}
