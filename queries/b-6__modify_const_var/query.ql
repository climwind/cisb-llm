/**
 * @name CISB: Const Variable Modified via Pointer Cast
 * @description Detects writes to const-qualified variables through pointer
 *              casts that strip const. The compiler may cache the pre-write
 *              value in a register, causing subsequent reads to observe a
 *              stale value.
 * @kind problem
 * @problem.severity warning
 * @precision medium
 * @id cpp/cisb-const-cast-bypass
 * @tags security, cisb, compiler-optimization
 */
import cpp
import query

from ConstNonVolatileVar cv, Expr writeSite
where constWriteViaPointer(cv, writeSite)
select writeSite, "Const variable '$@' is written via pointer cast — compiler may cache stale value.",
  cv, cv.getName()
