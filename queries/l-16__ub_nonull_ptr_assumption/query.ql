/**
 * @name Null check eliminated due to inline assembly memory operand
 * @description GCC's -fdelete-null-pointer-checks optimization treats inline assembly memory operands as pointer dereferences,
 *              incorrectly eliminating subsequent null checks on those pointers. This can lead to security issues.
 * @kind problem
 * @id cpp/cisb/null-check-eliminated-by-asm-memory-operand
 * @problem.severity error
 * @precision high
 * @tags security
 * @tags compiler-introduced
 */

import cpp
import NullCheckEliminatedByAsmMemoryOperand

from AsmStmt asm, NullCheckExpr check, Variable v
where
  asmMemoryDerefOperand(asm, v) and
  check.getCheckedVariable() = v and
  asmDominatesNullCheck(asm, check)
select check, "Null check on $@ might be eliminated because the inline assembly memory operand on $@ is treated as a pointer dereference by the compiler.", v, v.getName(), asm, asm.getLocation().toString()
