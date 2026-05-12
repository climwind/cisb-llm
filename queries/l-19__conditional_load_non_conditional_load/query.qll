import cpp

/**
 * Holds if `e` is an expression that writes to a global or static variable.
 * This includes direct assignments and calls to memory clear functions.
 */
predicate writesToSharedVariable(Expr e) {
  // Direct assignment to a global/static variable
  exists(AssignExpr ass, VariableAccess va |
    e = ass and
    ass.getLValue() = va and
    va.getTarget().isStatic()
  )
  or
  // Function call like memset(), bzero() to a global/static variable
  exists(FunctionCall call, AddressOfExpr addr, VariableAccess va |
    e = call and
    (
      call.getTarget().hasName("memset") or
      call.getTarget().hasName("__builtin_memset") or
      call.getTarget().getName().matches("%memset") or
      call.getTarget().hasName("bzero") or
      call.getTarget().hasName("explicit_bzero") or
      call.getTarget().getName().matches("%bzero") or
      call.getTarget().getName().matches("__builtin_.*zero")
    ) and
    addr = call.getArgument(0) and
    addr.getOperand() = va and
    va.getTarget().isStatic()
  )
}

/**
 * Holds if `cond` is an expression that checks a synchronization variable.
 * The condition can be a relational expression (== / !=) with NULL/0, a logical NOT, or a raw variable use.
 */
predicate isConditionOnSyncVariable(Expr cond) {
  exists(Variable v |
    cond.(ComparisonOperation).getAnOperand().(VariableAccess).getTarget() = v and v.isStatic()
    or
    cond.(NotExpr).getOperand().(VariableAccess).getTarget() = v and v.isStatic()
    or
    cond.(VariableAccess).getTarget() = v and v.isStatic()
  )
}

/**
 * A pattern where a conditional store to a shared variable is guarded by a condition on a synchronization variable.
 */
class ConditionalStore extends Expr {
  Expr condition;
  Variable writtenVar;
  Variable syncVar;

  ConditionalStore() {
    exists(IfStmt ifStmt |
      this.getEnclosingStmt().getParentStmt*() = ifStmt and
      (
        this.getEnclosingStmt() = ifStmt.getThen() or
        this.getEnclosingStmt() = ifStmt.getElse()
      ) and
      condition = ifStmt.getCondition() and
      isConditionOnSyncVariable(condition) and
      writesToSharedVariable(this) and
      exists(VariableAccess va |
        condition.getAChild*() = va and
        syncVar = va.getTarget()
      ) and
      exists(VariableAccess va2 |
        this.getAChild*() = va2 and
        writtenVar = va2.getTarget() and
        writtenVar.isStatic() and
        writtenVar != syncVar
      )
    )
  }

  /**
   * Gets the condition expression guarding the store.
   */
  Expr getCondition() { result = condition }

  /**
   * Gets the variable being written.
   */
  Variable getWrittenVariable() { result = writtenVar }

  /**
   * Gets the synchronization variable used in the condition.
   */
  Variable getSyncVariable() { result = syncVar }
}

/**
 * A query predicate that exposes all instances for use in .ql files.
 */
query predicate conditionalStoreQuery(Expr store, Expr cond, Variable writtenVar, Variable syncVar) {
  exists(ConditionalStore cs |
    store = cs and
    cond = cs.getCondition() and
    writtenVar = cs.getWrittenVariable() and
    syncVar = cs.getSyncVariable()
  )
}
