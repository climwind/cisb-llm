/**
 * @name CISB: Dead Store Elimination of memset/bzero
 * @description Detects calls to memset/bzero on local variables that may be
 *              eliminated by compiler dead-store elimination when the buffer
 *              is passed to free() without subsequent reads.
 * @kind problem
 * @problem.severity warning
 * @precision medium
 * @id cpp/cisb-dse-memset
 * @tags security, cisb, compiler-optimization
 */
import cpp
import query

// Phase 1: Syntax-only — tag every MemClearCall
from MemClearCall m
where m.getBufferVariable() instanceof LocalVariable
select m, "memset/bzero call on local variable '$@' — may be eliminated by DSE.",
  m.getBufferVariable(), m.getBufferVariable().getName()
