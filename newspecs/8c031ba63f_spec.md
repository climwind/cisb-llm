# CISB Specification

## Vulnerability Description

**Source**
8c031ba63f

**Description**
In the PARISC bootloader, gcc-7 optimizes byte-wise accesses to the external variable `output_len` (declared as `extern __le32`) into a word access, assuming natural alignment. Because the actual memory address is unaligned, this causes an unaligned access fault and boot panic.

**Evidence**
The compiler assumes that a 32-bit external integer is aligned to a 4-byte boundary, so it replaces the byte-wise load sequence in `get_unaligned_le32()` with a single 32-bit load. At runtime, the address of `output_len` is not aligned, triggering an unaligned access exception, leading to bootloader panic.

**Requirement**
Compiler: gcc-7 or later (possibly other compilers that perform similar alignment-based optimizations). Optimization flags: at least -O2 or -Os. Architecture: PARISC (or any hardware that traps unaligned memory accesses). The variable must reside in a memory region that does not guarantee 4-byte alignment.

**Mitigation**
Declare the variable with an explicit alignment attribute (`__attribute__((__aligned__(1)))`) to prevent the compiler from assuming natural alignment. Alternatively, avoid using normal typed accesses for unaligned data; use `memcpy` or explicitly byte-wise loads that the compiler does not optimize away (e.g., by using `volatile` or compiler barriers).

---

## Code Pattern

```json
{
  "triggers": [
    "Compiler optimization converts byte-wise access to word access",
    "External variable with alignment mismatch",
    "Runtime unaligned address"
  ],
  "vulnerable_pattern": "An external variable of a type with a size greater than 1 (e.g., `int`, `long`, `__le32`) is accessed through byte-wise operations (e.g., `get_unaligned_le32()`), but the compiler optimizes the sequence into a single load/store instruction because it assumes the variable is aligned according to its type. The actual memory location is unaligned, leading to a trap.",
  "ql_constraints": "Match an extern variable declaration whose type has sizeof > 1 and no explicit alignment attribute. Then, match any function that accesses this variable through a sequence of byte loads that can be merged: for example, a call to `get_unaligned_le32()` where the argument points to the variable, or an inline expression that loads multiple bytes and combines them via shifts and ORs. The prototype from the report is: variable `output_len` of type `__le32` (effectively `uint32_t`) accessed via `get_unaligned_le32()`. CodeQL can track data flow from the variable's address to such an expression.",
  "scope_assumptions": [
    "The variable is declared in one compilation unit and accessed in another (extern)"
  ],
  "control_flow_assumptions": [],
  "environment_assumptions": [
    "Compiler version gcc ≥ 7",
    "Optimization level at least -O2 or -Os",
    "Target architecture that faults on unaligned memory access (e.g., PARISC, ARM with strict alignment, MIPS, etc.)",
    "The variable's actual address is not guaranteed to be aligned to its type's alignment"
  ]
}
```

---

## Provenance

- Source analysis: \\wsl.localhost\Ubuntu\home\test\my-awesome-project\cisb-llm\kernel\P\8c031ba63f_analysis.md
- Source id: 8c031ba63f
- Digest: available
- Generated at: 2026-05-15T08:17:20.425790+00:00
- Model: deepseek-v4-pro
