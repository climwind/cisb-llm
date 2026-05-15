# CISB Specification

## Vulnerability Description

**Source**
Commit a9d57ef15c in Linux kernel repository

**Description**
GCC versions < 8.4.0, when retpolines are enabled (CONFIG_RETPOLINE=y), generate switch jump tables for switch statements with more than a default number of cases (typically >20). These jump tables introduce indirect jumps (e.g., jmp *reg) that are not protected by retpolines, opening a Spectre v2 branch target injection attack surface.

**Evidence**
Without -fno-jump-tables, disassembly of a kernel built with older GCC and retpolines shows indirect branch instructions generated from switch statements. These indirect jumps can be exploited via BTB poisoning to speculatively execute attacker-chosen gadgets, bypassing retpoline mitigations.

**Requirement**
Compiler: GCC version < 8.4.0. Configuration: CONFIG_RETPOLINE=y. Source code: a switch statement with enough case labels to trigger jump table generation (typically >20 for x86).

**Mitigation**
Add '-fno-jump-tables' to KBUILD_CFLAGS when CONFIG_RETPOLINE is enabled and compiler is GCC < 8.4.0. This forces the compiler to emit conditional branches (if-else chains) instead of jump tables, eliminating the vulnerable indirect jumps. Alternatively, upgrade to GCC >= 8.4.0, which adjusts the threshold or avoids jump tables under retpolines.

---

## Code Pattern

```json
{
  "triggers": [
    "GCC version < 8.4.0",
    "CONFIG_RETPOLINE enabled",
    "Switch statement with many cases (e.g., >20)",
    "Absence of -fno-jump-tables compiler flag"
  ],
  "vulnerable_pattern": "A switch statement with a large number of case labels (typically >20) compiled with GCC < 8.4.0 and retpolines enabled, without -fno-jump-tables, results in the compiler emitting an indirect jump table. This table-based dispatch creates Spectre-vulnerable indirect branches that retpolines cannot mitigate.",
  "ql_constraints": "The vulnerability is not a source-level coding error but a compiler behavior combined with missing build flags. CodeQL can identify potentially affected switch statements by matching SwitchStmt nodes where the count of CaseStmt children exceeds a threshold (e.g., 20). The query should report such switch statements in kernel source files, noting that if built with GCC < 8.4.0 and CONFIG_RETPOLINE=y without -fno-jump-tables, they represent a Spectre v2 attack surface.",
  "scope_assumptions": [
    "The switch statement resides in kernel source code compiled with retpoline support enabled (CONFIG_RETPOLINE)."
  ],
  "control_flow_assumptions": [],
  "environment_assumptions": [
    "GCC version less than 8.4.0",
    "Retpolines enabled (CONFIG_RETPOLINE=y)",
    "x86 architecture (retpolines are x86-specific)"
  ]
}
```

---

## Provenance

- Source analysis: \\wsl.localhost\Ubuntu\home\test\my-awesome-project\cisb-llm\kernel\P\a9d57ef15c_analysis.md
- Source id: a9d57ef15c
- Digest: available
- Generated at: 2026-05-15T06:57:54.939285+00:00
- Model: deepseek-v4-pro
