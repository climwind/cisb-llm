/**
 * @name Uninitialized struct padding exposed to user space on sparc64
 * @description On sparc64, structs may contain implicit padding that remains uninitialized when fields are assigned individually. If such a struct is copied to user space, sensitive kernel stack data may be leaked.
 * @kind problem
 * @id cpp/cisb/sparc64-padding-leak
 * @problem.severity high
 * @precision medium
 * @tags security
 */

import cpp
import query

from Variable v
where isSparc64() and structWithUninitializedPadding(v)
select v, "Struct $@ has uninitialized padding due to individual field assignments and is exposed to user space.", v, v.getName()
