/**
 * @name Const variable modified via pointer cast
 * @description Writing to a const-qualified variable through a pointer cast invokes undefined behavior;
 *              compilers may optimize away the write based on assumed immutability.
 * @kind problem
 * @id cpp/const-variable-modification
 * @problem.severity high
 * @precision medium
 * @tags security
 *       correctness
 */

import cpp
import ConstVarModificationLibrary

from ConstVarModification cvm, VariableDecl v
where cvm.getModifiedVar() = v
select cvm, "Modification of const variable '$@' via pointer cast. Declaration: $@.",
  v, v.getName(), v, "defined here"
