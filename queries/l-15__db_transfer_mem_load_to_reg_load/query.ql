/**
 * @name Return register mismatch in memory operation functions
 * @description Detects functions expected to return their first argument but return a different value due to modification of the first parameter or return of a different expression.
 * @kind problem
 * @problem.severity error
 * @precision high
 * @id cpp/return-register-mismatch
 * @tags security
 */

import cpp
import query

from ReturnRegisterMismatch f
select f, f.toString()
