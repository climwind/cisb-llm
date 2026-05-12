/**
 * @name Conditional store may be made unconditional by compiler optimization
 * @description A conditional store to a shared memory object guarded by a synchronization check may be
 *   optimized into an unconditional store by the compiler, bypassing synchronization and introducing data races.
 * @kind path-problem
 * @problem.severity high
 * @precision medium
 * @id cpp/conditional-store-optimization
 * @tags security
 *       correctness
 */

import cpp
import ConditionalStoreLibrary

from Expr store, Expr cond, Variable writtenVar, Variable syncVar
where conditionalStoreQuery(store, cond, writtenVar, syncVar)
select store, cond, writtenVar, syncVar,
  "Conditional store to $" + writtenVar.getName() + " guarded by synchronization variable $" +
    syncVar.getName() + " may be optimized to unconditional store by compiler."
