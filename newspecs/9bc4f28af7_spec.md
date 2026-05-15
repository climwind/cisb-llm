# CISB Specification

## Vulnerability Description

**Source**
9bc4f28af75a91aea0ae383f50b0a430c4509303

**Description**
Compiler may split PTE assignments into multiple writes when WRITE_ONCE() is not used, creating a window where an interim non-present PTE could be exploited (e.g., L1TF). Use WRITE_ONCE() to force a single atomic write.

**Evidence**
Pre-patch: compiler could emit multiple store instructions for a single PTE assignment. Post-patch: WRITE_ONCE() ensures a single store, eliminating the transient non-present state that could leak via L1TF.

**Requirement**
Compiler optimization that splits stores (e.g., -O2), x86 architecture with page table entries that may require multiple stores to write completely, and a kernel code path that modifies page table entries without a barrier.

**Mitigation**
Use WRITE_ONCE() macro for all page table entry assignments, or replace plain writes with functions like set_pte() that internally use WRITE_ONCE().

---

## Code Pattern

```json
{
  "triggers": [
    "Plain assignment to a page table entry pointer without WRITE_ONCE()",
    "Compiler optimization that may split the assignment into multiple store instructions"
  ],
  "vulnerable_pattern": "A plain assignment to a dereferenced pointer of a page table entry type (pte_t, pmd_t, etc.) without WRITE_ONCE(), e.g. *ptep = native_make_pte(0);",
  "ql_constraints": "The pattern matches assignments of the form *ptr = expr where ptr has type pointer to a page table entry typedef (pte_t, pmd_t, pud_t, p4d_t, pgd_t) and the assignment is not wrapped in a WRITE_ONCE() or similar atomic access macro, nor is it part of a function known to enforce atomicity (e.g., set_pte_at). The dereference and assignment must be at a location where the compiler could freely reorder or split the store (i.e., no volatile qualifier). In the prototype, the left side is a simple pointer dereference of a parameter named ptep.",
  "scope_assumptions": [
    "The assignment occurs in a function that directly modifies page table entries, typically within architecture-specific page table handling code (arch/x86/include/asm/pgtable*.h, arch/x86/mm/pgtable.c)."
  ],
  "control_flow_assumptions": [],
  "environment_assumptions": [
    "The compiler is capable of splitting a store into multiple instructions (common at -O2 or higher).",
    "The target architecture is x86, but similar issues may exist on other architectures where page table entries are wider than the natural word size."
  ]
}
```

---

## Provenance

- Source analysis: \\wsl.localhost\Ubuntu\home\test\my-awesome-project\cisb-llm\kernel\P\9bc4f28af7_analysis.md
- Source id: 9bc4f28af7
- Digest: available
- Generated at: 2026-05-15T06:53:22.917423+00:00
- Model: deepseek-v4-pro
