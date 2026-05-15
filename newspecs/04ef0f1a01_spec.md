# CISB Specification

## Vulnerability Description

**Source**
04ef0f1a01

**Description**
Compiler assumes 8-byte alignment for struct ib_sa_mcmember_data and optimizes memcpy into an 8-byte load instruction (ldx). The pointer to this struct in send_reply_to_slave() may be only 4-byte aligned, causing unaligned access faults on architectures with strict alignment requirements.

**Evidence**
Without __packed __aligned(4), the compiler turns an 8-byte memcpy into an aligned load/store instruction. When the pointer is 4-byte aligned, the instruction triggers an unaligned access trap, leading to kernel crash or data corruption.

**Requirement**
GCC with -O2 or similar, architecture with strict alignment (e.g., SPARC), struct size multiple of 8 bytes, pointer alignment less than struct size alignment.

**Mitigation**
Mark struct with __attribute__((packed, aligned(4))) to force compiler to treat all accesses as potentially unaligned and avoid generating aligned load instructions.

---

## Code Pattern

```json
{
  "triggers": [
    "Compiler optimizes an 8-byte memcpy to an aligned 8-byte load/store instruction.",
    "Target pointer is only 4-byte aligned due to its origin in a buffer or union.",
    "Architecture enforces strict alignment, trapping on unaligned access."
  ],
  "vulnerable_pattern": "A struct with size multiple of 8 bytes (e.g., 16 bytes) is copied via memcpy from a pointer that is only 4-byte aligned, and the struct definition lacks packed/aligned attributes, allowing the compiler to assume natural alignment for the struct (8-byte) and emit an aligned load instruction.",
  "ql_constraints": "Match struct definitions that are not annotated with __packed or __aligned, have a size that is a multiple of the natural alignment assumed by the compiler (e.g., 8), and are accessed via memcpy (or direct assignment) where the source or destination pointer may be only 4-byte aligned (e.g., derived from a char* buffer or a struct member with lower alignment). Specifically, find struct types S where sizeof(S) % 8 == 0 and no __packed attribute, then locate memcpy calls where the first or second argument is a pointer to S and the pointer's provenance includes a cast from a type with alignment less than 8.",
  "scope_assumptions": [
    "The struct definition is visible in the compilation unit where the access occurs."
  ],
  "control_flow_assumptions": [],
  "environment_assumptions": [
    "Compiler optimization level -O2 or higher that enables memcpy-to-load/store transformation.",
    "Strict-alignment architecture where unaligned access causes a fault (e.g., SPARC, some ARM)."
  ]
}
```

---

## Provenance

- Source analysis: \\wsl.localhost\Ubuntu\home\test\my-awesome-project\cisb-llm\kernel\P\04ef0f1a01_analysis.md
- Source id: 04ef0f1a01
- Digest: available
- Generated at: 2026-05-15T06:41:31.605774+00:00
- Model: deepseek-v4-pro
