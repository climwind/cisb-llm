# CISB Specification

## Vulnerability Description

**Source**
Linux kernel commit ede6b6bc43 (drivers/gpu/drm/radeon/radeon_uvd.c)

**Description**
GCC's loop optimization transforms a for-loop writing constant zeros to memory into a __memset call. When the target memory is device memory (I/O memory), __memset does not perform the necessary access semantics and causes a crash on arm64. The developer expected the loop to be preserved, but the compiler treated the memory as ordinary RAM.

**Evidence**
In radeon_uvd_get_create_msg, a for loop writes zeros to msg buffer (device memory). GCC 8.3.1 optimized it to __memset, leading to a kernel crash with __memset in the call trace on arm64.

**Requirement**
GCC version that performs loop-to-memset optimization (e.g., 8.3.1 with -O2 or higher), arm64 target, device memory region mapped as normal memory pointer (not annotated with __iomem).

**Mitigation**
Replace direct pointer writes with architecture-specific I/O accessors like writel(); alternatively, declare the pointer as volatile or use compiler barriers to inhibit memset transformation; alternatively, compile with -fno-builtin-memset or -fno-tree-loop-distribute-patterns.

---

## Code Pattern

```json
{
  "triggers": [
    "Compiler loop-to-memset optimization",
    "Target memory is device memory requiring special access",
    "Pointer is not marked as volatile or __iomem"
  ],
  "vulnerable_pattern": "A for loop that iterates over a range of indices and writes a constant value (e.g., zero) to consecutive elements of a non-volatile pointer array, where the pointer may point to device memory but is not annotated as such. Example: for (int i = 11; i < 1024; ++i) msg[i] = cpu_to_le32(0);",
  "ql_constraints": "Match a for loop where the loop body contains an assignment to an element of an array pointer, indexed by the loop variable, and the assigned value is a compile-time constant. The base pointer should not have a volatile or __iomem qualified type. Example: for (int i = lower; i < upper; ++i) { buf[i] = constant; }. The assignment may be through a macro like cpu_to_le32().",
  "scope_assumptions": [
    "The loop and the pointer variable are within the same function."
  ],
  "control_flow_assumptions": [
    "The loop body contains only the assignment, or does not contain memory barriers, volatile accesses, or function calls that would inhibit memset recognition."
  ],
  "environment_assumptions": [
    "GCC compiler with loop-to-memset optimization enabled",
    "Target architecture is arm64 (or any where __memset on device memory is invalid)",
    "The memory pointed to is device memory (I/O memory) without proper annotation in the source"
  ]
}
```

---

## Provenance

- Source analysis: \\wsl.localhost\Ubuntu\home\test\my-awesome-project\cisb-llm\kernel\P\ede6b6bc43_analysis.md
- Source id: ede6b6bc43
- Digest: available
- Generated at: 2026-05-15T07:04:26.925565+00:00
- Model: deepseek-v4-pro
