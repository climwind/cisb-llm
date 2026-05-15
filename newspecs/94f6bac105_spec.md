# CISB Specification

## Vulnerability Description

**Source**
94f6bac105

**Description**
GCC 3.4.6 inlines and merges two consecutive calls to have_cpuid_p() into one, assuming purity, causing missed CPUID detection on Cyrix CPUs. The second call is not re-evaluated after c_identify() enables CPUID, leading to failure to detect ARR registers.

**Evidence**
Two calls to have_cpuid_p() in the kernel code: the first returns false because CPUID is not yet enabled on Cyrix; c_identify() then enables CPUID; the second call should return true but the compiler reuses the first call's false result, skipping re-check and causing missed ARR register detection.

**Requirement**
GCC version 3.4.6 with optimization levels that perform inlining and CSE (e.g., -O2). x86 architecture, Cyrix CPUs in affected scenarios.

**Mitigation**
Add a memory clobber to the inline assembly in flag_is_changeable_p() to prevent CSE across its calls. Alternatively use volatile, function attributes like 'noinline', or compilation flags like -fno-builtin or disabling specific optimizations.

---

## Code Pattern

```json
{
  "triggers": [
    "compiler common subexpression elimination merges two calls to a hardware-state-reading function",
    "inlining of static inline function allows cross-call optimization",
    "function is assumed pure but reads mutable hardware state"
  ],
  "vulnerable_pattern": "Two calls to function F() are made in the same scope, with a call to function G() interleaved that modifies the hardware state read by F(). The compiler inlines F() and treats it as pure/idempotent, eliminating the second call and reusing the result of the first.",
  "ql_constraints": "Match a function that contains two calls to the same function F, with an intervening call to another function G, where F is declared inline (or static inline) and contains inline assembly that reads from a hardware register or performs a side-effecting operation without adequate clobber declarations. The compiler may eliminate the second call to F after inlining. In this prototype, F maps to have_cpuid_p() and G maps to c_identify(). Specific function names are not required; the pattern is about the call ordering and inlining behavior.",
  "scope_assumptions": [
    "the two calls to the check function and the intervening modifier call occur in the same function"
  ],
  "control_flow_assumptions": [
    "the second call to the check function is reachable after the modifier call without an intervening check that could alter control flow"
  ],
  "environment_assumptions": [
    "GCC version that performs aggressive CSE across inlined function boundaries (e.g., 3.4.6)",
    "optimization level -O2 or higher that enables inlining and CSE",
    "x86 architecture where inline assembly is used to read CPU flags"
  ]
}
```

---

## Provenance

- Source analysis: \\wsl.localhost\Ubuntu\home\test\my-awesome-project\cisb-llm\kernel\P\94f6bac105_analysis.md
- Source id: 94f6bac105
- Digest: available
- Generated at: 2026-05-15T08:18:34.225574+00:00
- Model: deepseek-v4-pro
