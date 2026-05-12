/**
 * @name Struct alignment mismatch in linker section
 * @description Static or global struct variables placed in a linker section without explicit alignment attribute may become misaligned due to compiler default alignment changes.
 * @kind problem
 * @id cpp/cisb/struct-alignment-section
 * @problem.severity high
 * @precision medium
 * @tags security
 */

import cpp
import query

from VariableInSectionWithoutAlignment v
select v, "Struct variable in section without explicit alignment attribute."
