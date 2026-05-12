/**
 * @name Large switch statement with retpoline enabled
 * @description Switch statements with many cases may be compiled using jump tables,
 *   which under CONFIG_RETPOLINE produce indirect jumps vulnerable to Spectre v2.
 *   This query flags such switches when -fno-jump-tables is not used.
 * @kind problem
 * @problem.severity high
 * @precision medium
 * @id cpp/switch-retpoline-jump-table
 * @tags security
 *      spectre
 *      retpoline
 */

import cpp
import LargeSwitchRetpoline

from LargeSwitch ls
where
  isRetpolineDefined() and
  not hasJumpTablesDisabled()
select ls, "This switch statement with $@ cases compiled under CONFIG_RETPOLINE may generate a jump table with vulnerable indirect jumps.", ls.getNumberOfCaseStmts()
