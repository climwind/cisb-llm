# CISB Specification

## Vulnerability Description

**Source**
commit 86c38a31aa

**Description**
GCC 4.5 changed default structure alignment to the largest member alignment (32 bytes by default), breaking kernel assumptions that structures placed in the _ftrace_events section would be packed with 4-byte alignment. This leads to misaligned access and function pointer corruption during initialization, causing boot failure.

**Evidence**
The kernel compiled successfully with GCC 4.5, but at boot, the code iterates over the _ftrace_events section assuming contiguous struct ftrace_event_call entries. Due to 32-byte alignment, padding is inserted between entries, so pointer arithmetic with sizeof(struct ftrace_event_call) skips over real data and reads padding as function pointers, leading to crashes or control flow hijack.

**Requirement**
GCC version 4.5 or later with default alignment (no -malign-data=abi). Architecture is x86-64 or similar where alignment is enforced. Compilation without -fpack-struct.

**Mitigation**
Add __attribute__((aligned(4))) to all struct ftrace_event_call declarations placed in the _ftrace_events section, or compile with -malign-data=abi to revert to 4-byte default alignment.

---

## Code Pattern

```json
{
  "triggers": [
    "GCC 4.5+ default 32-byte alignment for structures without explicit alignment",
    "Structures placed contiguously in a linker section via section attribute",
    "Iteration over the section using pointer arithmetic with sizeof(struct) stride"
  ],
  "vulnerable_pattern": "A structure type T without explicit alignment attribute (or with alignment less than the compiler's default maximum) is used to declare multiple static or global objects placed into a custom linker section (e.g., __attribute__((section(\".my_section\")))). Code iterates over these objects using a pointer p to T, advancing by sizeof(T) (e.g., p++ or p += 1), and reads their members. Because the compiler aligns each object to a boundary larger than sizeof(T), gaps appear, and the pointer arithmetic overshoots the intended objects, reading padding instead.",
  "ql_constraints": "Find structure types without an alignment attribute (i.e., not declared with __attribute__((aligned))). Find variables of that type that have a section attribute placing them in the same section. Identify loops that use pointer arithmetic on such variables' addresses, advancing by sizeof the structure type. Confirm that the structure type's alignment as determined by the compiler (e.g., via __alignof__) is greater than its size.",
  "scope_assumptions": [
    "Multiple global or static variables of the same structure type, each placed in the same custom linker section via section attribute."
  ],
  "control_flow_assumptions": [
    "A loop or iteration over the section using start/end symbols or pointer arithmetic with stride sizeof(structure type)."
  ],
  "environment_assumptions": [
    "GCC 4.5 or later without -malign-data=abi or -fpack-struct. Use of section attribute and linker script to place data in a custom section."
  ]
}
```

---

## Provenance

- Source analysis: \\wsl.localhost\Ubuntu\home\test\my-awesome-project\cisb-llm\kernel\P\86c38a31aa_analysis.md
- Source id: 86c38a31aa
- Digest: available
- Generated at: 2026-05-15T06:26:56.742751+00:00
- Model: deepseek-v4-pro
