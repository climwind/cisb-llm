/**
 * @name Const variable modified via pointer cast
 * @description Writing to a const-qualified variable through a pointer cast invokes undefined behavior;
 *              compilers may optimize away the write based on assumed immutability.
 * @kind problem
 * @problem.severity warning
 * @id cpp/const-variable-modification
 * @tags security
 */

import cpp
import query

from ConstVarModification cvm
select cvm, "Const variable '$@' modified via pointer cast.",
  cvm.getModifiedVar(), cvm.getModifiedVar().getName()
