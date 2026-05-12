/**
 * @id cpp/clang-optimization-removes-null-check-on-member-address
 * @name Clang optimization removes null check on struct member address in loop condition
 * @description Detects loops where the condition checks if the address of a struct member is non-null,
 *              which Clang may optimize to always-true when the member offset > 0, causing infinite loops.
 * @kind problem
 * @problem.severity warning
 * @precision medium
 * @tags security
 *       compiler-introduced
 *       infinite-loop
 *       clang-optimization
 */

import cpp
import MemberAddressNullCheck

from VulnerableLoop vl
select vl, "Loop condition contains a null check on struct member address that Clang may optimize to always-true, potentially causing infinite loop."
