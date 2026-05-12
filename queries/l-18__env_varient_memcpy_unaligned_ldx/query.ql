/**
 * @name IO Memory Access Using Standard Memory Function Compiler Optimization
 * @description Finds calls to standard memory functions (memset/memcpy) inside IO memory access wrapper functions, which may be optimized by GCC assuming aligned memory, leading to hardware faults on IO mappings that do not support unaligned accesses.
 * @kind problem
 * @severity high
 * @precision medium
 * @id cpp/io-memory-builtin-optimization
 * @tags security
 */

import cpp
import IOMemoryBuiltinOptimization

from VulnerableCallToBuiltinInIOAccessor call
where hasNoVolatileAsmBarrier(call.getEnclosingFunction())
select call, "Call to $@ inside IO accessor $@ may be optimized by compiler, causing hardware faults on unaligned IO memory.",
  call.getTarget(), call.getEnclosingFunction()
