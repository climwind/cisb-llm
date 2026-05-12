/**
 * @id cpp/unaligned-struct-access-missing-alignment-attribute
 * @name Unaligned memory access due to missing struct alignment attributes
 * @description A memory access (struct assignment, memcpy, pointer dereference, array access) involves a struct type without __packed or __aligned attributes. Compiler may generate aligned load/store instructions causing faults on strict-alignment architectures.
 * @kind problem
 * @problem.severity error
 * @precision medium
 * @tags security
 *       compiler-introduced
 *       CISB
 *       alignment
 */

import cpp
import query::UnalignedStructAccess

from PotentialUnalignedAccess access, Struct s
where access.getStruct() = s
select access, "Potential unaligned access to struct '" + s.getName() + "' which lacks alignment attributes."
