# CISB Specification

## Vulnerability Description

**Source**
commit beaec533fc

**Description**
Clang optimization assumes that the address of a struct member with offset >0 cannot be NULL, causing an infinite loop in list iteration macros that check &pos->member != NULL for termination.

**Evidence**
The kernel contains llist_for_each_entry macros that iterate a linked list using a condition `&pos->member != NULL`. When compiled with Clang, the compiler optimizes away the NULL check, always evaluating the condition as true. This results in infinite loops at runtime, leading to CPU exhaustion and denial of service.

**Requirement**
Clang compiler with default optimization levels (e.g., -O2) on architectures where NULL is zero. The struct member must have a non-zero offset within the struct.

**Mitigation**
Use a compiler barrier such as casting the pointer to uintptr_t before taking the member address, e.g., `#define member_address_is_nonnull(ptr, member) ((uintptr_t)&(ptr)->member != 0)`. Alternatively, compile with `-fno-delete-null-pointer-checks`.

---

## Code Pattern

```json
{
  "triggers": [
    "Clang optimization assumes &ptr->member cannot be NULL when member offset > 0",
    "Loop condition uses &ptr->member != NULL where ptr is derived from a possibly NULL node pointer via container_of"
  ],
  "vulnerable_pattern": "A for-loop iterates over a linked list using a pointer `pos` obtained from a possible NULL node pointer (e.g., via container_of). The loop termination condition is `&pos->member != NULL`, where `member` is a struct field. The compiler optimizes this to always true, eliminating the loop exit.",
  "ql_constraints": "Match a for-loop where the condition is a binary `!=` expression with left operand being an `AddressOfExpr` of a `MemberAccess` (ptr->field) and right operand being a null pointer constant (e.g., NULL or 0). The pointer variable should be assigned from a macro like `container_of` that computes the containing object from a member pointer, where the member pointer may originate from a list node that could be NULL. Example: `&pos->member != NULL` inside the for loop condition of `llist_for_each_entry`. Equivalent forms such as `&pos->member != 0` or `NULL != &pos->member` may also apply.",
  "scope_assumptions": [
    "The pattern occurs in a macro or inline function defining a list iteration loop."
  ],
  "control_flow_assumptions": [
    "The condition is evaluated at the start of each loop iteration, and the loop body accesses `pos->member.next` or equivalent to advance to the next element."
  ],
  "environment_assumptions": [
    "Clang compiler is used with optimization level -O2 or higher.",
    "The struct member has a positive offset (offset > 0)."
  ]
}
```

---

## Provenance

- Source analysis: \\wsl.localhost\Ubuntu\home\test\my-awesome-project\cisb-llm\kernel\P\beaec533fc_analysis.md
- Source id: beaec533fc
- Digest: available
- Generated at: 2026-05-15T08:21:31.120021+00:00
- Model: deepseek-v4-pro
