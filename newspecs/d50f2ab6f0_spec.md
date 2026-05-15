# CISB Specification

## Vulnerability Description

**Source**
d50f2ab6f0

**Description**
The ext4 file system code performs a left-shift operation (1 << s_log_groups_per_flex) before checking its result for zero to catch invalid values. If s_log_groups_per_flex is greater than or equal to the integer width, the shift invokes undefined behavior. Compilers (e.g., Clang 3.0) exploit this UB to optimize away the subsequent zero-check, assuming the result can never be zero. This eliminates the sanity check, leaving a divide-by-zero vulnerability when groups_per_flex is later used as a divisor.

**Evidence**
The source code contains: groups_per_flex = 1 << s_log_groups_per_flex; if (groups_per_flex == 0) { /* error handling */ }. After compilation with Clang 3.0, the if statement is removed. An attacker can provide a corrupted superblock with s_log_groups_per_flex >= 32, causing undefined shift behavior. Without the check, groups_per_flex may become zero (or any value) and later is used as a divisor, triggering a divide-by-zero crash.

**Requirement**
A compiler that performs undefined-behavior-based optimizations for left-shift (e.g., Clang 3.0+, GCC with -O2). The shift amount variable (s_log_groups_per_flex) must be attacker-controllable, e.g., read from an untrusted superblock. The vulnerability is architecture-independent but can manifest on x86 where shift truncation may produce zero.

**Mitigation**
Validate the shift amount before the shift: if (shift_amount >= 0 && shift_amount < width_of_type) { /* safe shift */ } else { /* error */ }. Do not rely on inspecting the result of an undefined shift. The upstream fix moves the check before the shift operation.

---

## Code Pattern

```json
{
  "triggers": [
    "Left shift with a variable amount that is not bounds-checked",
    "A zero-check on the shift result is used for error detection",
    "Compiler optimizations remove the zero-check due to undefined behavior assumptions"
  ],
  "vulnerable_pattern": "A left-shift operation (e.g., `1 << e`) whose result is stored in a local variable `v`. Later, `v` is compared to zero (e.g., `if (v == 0)`) to detect an invalid shift amount. The variable `e` is not range-checked to ensure it is less than the width of the shifted type before the shift.",
  "ql_constraints": "There is a ShiftLeftExpr `s` where the left operand is the integer constant `1` and the right operand is a variable `e`. The result of `s` is assigned to a local variable `v`. There exists a ConditionBranch or EqualityTest that uses `v`, comparing it to the constant `0`. The variable `e` is not bounded to be less than the type width (e.g., sizeof(int)*8) prior to the shift. The zero-check is post-dominated by the shift assignment. Note: the null-check in this case uses `if (v == 0)`; equivalent forms such as `!v` or `v != 0` may also apply.",
  "scope_assumptions": [
    "The shift and the zero-check occur within the same function."
  ],
  "control_flow_assumptions": [
    "The zero-check is reachable from the shift assignment without an intervening write to `v`."
  ],
  "environment_assumptions": [
    "Compiler optimizations exploit the undefined behavior of left-shift by an out-of-range amount (C standard: shift >= width of promoted left operand is UB). The compiler may deduce that the shift result cannot be zero, eliminating the subsequent zero-check."
  ]
}
```

---

## Provenance

- Source analysis: \\wsl.localhost\Ubuntu\home\test\my-awesome-project\cisb-llm\kernel\P\d50f2ab6f0_analysis.md
- Source id: d50f2ab6f0
- Digest: available
- Generated at: 2026-05-15T07:02:50.261006+00:00
- Model: deepseek-v4-pro
