# CISB Specification

## Vulnerability Description

**Source**
45a94d7cd4

**Description**
GCC 4.1.2 optimizes away a second cpuid call after xsetbv() because it treats repeated cpuid with same inputs as redundant, even though the output changes due to xsetbv(). This causes incorrect xsave context size and kernel crash on processors with extended xsave state.

**Evidence**
Pre-fix: Second cpuid removed by optimizer, leading to incorrect context size. Post-fix: Volatile keyword ensures both cpuid calls execute as intended.

**Requirement**
GCC 4.1.2, x86 architecture, optimization enabled (e.g., -O2), processor with extended xsave state.

**Mitigation**
Add 'volatile' keyword to the inline asm for cpuid instruction to prevent compiler from removing or reordering the call.

---

## Code Pattern

```json
{
  "triggers": [
    "compiler optimization treats repeated cpuid with same inputs as redundant",
    "xsetbv() changes cpuid output between calls"
  ],
  "vulnerable_pattern": "A function containing an inline assembly statement that performs a cpuid instruction, called twice in sequence with the same input values, where the second call is expected to produce different output due to a side effect (e.g., xsetbv) executed between the calls. The inline assembly lacks the 'volatile' qualifier.",
  "ql_constraints": "Match an inline assembly statement (asm(...)) that contains the cpuid instruction. The asm must not have the volatile qualifier. The function containing this asm is called twice in the same caller function, with the same input arguments, and there is a call to xsetbv (or similar side-effect instruction) between the two calls. The two calls must be in the same basic block or in a sequence where the compiler can prove the inputs are unchanged.",
  "scope_assumptions": [
    "within the same caller function",
    "two calls to the same inline function containing cpuid asm"
  ],
  "control_flow_assumptions": [
    "the two cpuid calls are in sequence without intervening branches that could change the inputs",
    "there is a call to xsetbv between the two cpuid calls"
  ],
  "environment_assumptions": [
    "x86 architecture",
    "compiler optimization level that enables redundant code elimination (e.g., -O2)",
    "GCC 4.1.2 or similar version that treats cpuid as pure"
  ]
}
```

---

## Provenance

- Source analysis: \\wsl.localhost\Ubuntu\home\test\my-awesome-project\cisb-llm\kernel\P\45a94d7cd4_analysis.md
- Source id: 45a94d7cd4
- Digest: available
- Generated at: 2026-05-15T08:25:09.265131+00:00
- Model: deepseek-chat
