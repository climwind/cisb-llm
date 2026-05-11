/**
 * @name CISB: Null Check on Struct Member Address Optimized Away
 * @description Detects null checks on the address of a struct member
 *              (&ptr->field == NULL). When the field has a positive offset
 *              from the struct base, the compiler proves the check is
 *              always-false and eliminates it entirely.
 * @kind problem
 * @problem.severity warning
 * @precision medium
 * @id cpp/cisb-member-address-null-check
 * @tags security, cisb, compiler-optimization
 */
import cpp
import query

from MemberAddressNullCheck check
select check, "Null check on struct member address — may be eliminated by compiler if field offset > 0."
