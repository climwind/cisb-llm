import cpp

/**
 * A switch statement that contains many case labels, making it a candidate
 * for jump-table code generation. The threshold of 20 comes from GCC's
 * historical default behaviour for -O2 and above.
 */
class PotentialJumpTableSwitch extends SwitchStmt {
  PotentialJumpTableSwitch() {
    count(this.getASwitchCase()) > 20
  }
}

/**
 * Holds if the switch statement is likely to be lowered using an indirect
 * jump via a jump table, introducing a Spectre-v2 susceptible indirect branch.
 * This is true for any switch that qualifies as a potential jump-table switch.
 */
predicate usesIndirectJump(SwitchStmt s) {
  s instanceof PotentialJumpTableSwitch
}

/**
 * Placeholder for the environmental conditions that make this CISB exploitable:
 * - GCC version < 8.4.0
 * - CONFIG_RETPOLINE defined (often checked via preprocessor)
 * - -fno-jump-tables not present in compilation flags
 * - x86 architecture (default for many kernel builds)
 *
 * In practice, CodeQL cannot inspect compiler flags; this predicate should be
 * refined with build-system metadata when available.
 */
predicate vulnerableEnvironment() {
  none() /* Phase 2: check CONFIG_RETPOLINE */
  // Phase 2: restrict to x86 via preprocessor macros like __i386__, __x86_64__.
  // Phase 2: verify that -fno-jump-tables is missing (requires build capture).
}
