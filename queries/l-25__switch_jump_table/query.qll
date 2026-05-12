import cpp

/**
 * A SwitchStatement that is likely to be compiled into a jump table
 * due to having many case labels. A large number of cases triggers
 * GCC's heuristic to emit a jump table for efficient dispatch.
 */
class LargeSwitch extends SwitchStatement {
  LargeSwitch() {
    this.getNumberOfCaseStmts() > 20
  }
}

/**
 * Holds if the macro CONFIG_RETPOLINE is defined in any preprocessor
 * directive in the database. This indicates retpoline mitigations are
 * enabled for the kernel build.
 */
predicate isRetpolineDefined() {
  any(MacroDefinition d | d.getName() = "CONFIG_RETPOLINE")
}

/**
 * Placeholder for checking whether -fno-jump-tables flag is present.
 * Since compiler flags are not directly accessible in CodeQL,
 * this predicate should be overridden by the query if the flag
 * can be determined from build metadata. By default, assume flag
 * is NOT present, which is the vulnerable case.
 */
predicate hasJumpTablesDisabled() {
  none() // Always false, meaning jump tables are NOT disabled
}
