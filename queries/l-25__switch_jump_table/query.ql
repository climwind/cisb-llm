/**
 * @name Potential Spectre v2 via switch jump tables (missing -fno-jump-tables)
 * @description Switch statements with many cases may be compiled into indirect jump tables
 *              that are vulnerable to Spectre v2 when retpoline mitigations are active.
 * @kind problem
 * @problem.severity warning
 * @precision medium
 * @id cpp/spectre-v2-switch-jump-table
 * @tags security
 *       spectre
 *       cwe-200
 */

import cpp
import query

from SwitchStmt s
where
  usesIndirectJump(s) and
  vulnerableEnvironment() and
  // Exclude switches that already have a compiler hint to suppress jump tables
  not s.getAnAttribute().getName() = "nocf_check"   // Linux kernel hint
select s,
  "Switch statement with " + count(s.getASwitchCase()) +
  " case labels may generate an indirect jump table vulnerable" +
  " to Spectre v2 when compiled without -fno-jump-tables."
