# CISB Analysis Report

**Title**
x86/retpolines: Disable switch jump tables when retpolines are enabled

**Issue**
GCC versions < 8.4.0 generate switch jump tables for cases > 20 under retpolines, creating indirect jumps vulnerable to Spectre v2.

**Tag**
Compiler-Introduced Security Bug

**Purpose**
Disable switch jump tables entirely under retpolines for gcc versions < 8.4.0 to align with newer gcc behavior and avoid expensive indirect jumps.

---

### Step-by-Step Analysis:
1. **Key Variables/Functionality**: KBUILD_CFLAGS modified in arch/x86/Makefile to include -fno-jump-tables when CONFIG_RETPOLINE is set and compiler is GCC.
2. **Compiler Behavior**: GCC < 8.4.0 defaults to generating jump tables for switch statements with > 20 cases, creating indirect jumps.
3. **Pre/Post Compilation**: Switch statements with > 20 cases now compile to conditional chains (if-else) instead of jump tables, increasing vmlinux size by 0.27%.
4. **Security Implications**: Eliminates indirect branches in switch statements that retpolines do not protect, reducing Spectre v2 branch target injection risk.
---

1. [yes] Did compiler accept the kernel code and compile it successfully? The commit successfully modifies arch/x86/Makefile to add -fno-jump-tables to KBUILD_CFLAGS when retpolines are enabled. The commit message indicates this was integrated into the kernel build system without compilation errors. This is a build configuration change, not a code fix, and the kernel compiled successfully with these flags.
2. [yes] Is the commit describing a runtime bug caused by optimization or default compiler behavior? The commit addresses a runtime issue caused by gcc's default compiler behavior. For gcc versions < 8.4.0, the compiler automatically generates switch jump tables for switch statements with more than 20 cases. This default optimization creates indirect jumps that are subject to retpoline overhead and are not protected by retpoline mitigations. The patch adds -fno-jump-tables to override this default behavior, confirming the issue stems from compiler defaults rather than source code bugs.
3. [yes] Without that optimization or default behavior, would the problematic difference disappear? Without gcc's default behavior of generating jump tables for switch cases > 20 (or with the -fno-jump-tables flag applied), the problematic difference would disappear. The issue stems from gcc < 8.4.0 automatically creating jump tables that produce indirect jumps subject to retpoline overhead. The patch forces -fno-jump-tables to disable this behavior, eliminating the indirect jumps from switch statements.
4. [yes] Did observable runtime behavior change after compilation? Observable runtime behavior changed after compilation. Switch statements with >20 cases that previously compiled to jump tables (indirect jumps through a table) now compile to conditional chains (if-else sequences). This eliminates indirect branch instructions from those code paths, changing speculative execution characteristics. The commit message also notes vmlinux size grows by 0.27% for older gcc, confirming a measurable change in the compiled output.
5. [yes] Does the change have direct or indirect security implications in kernel context? The change has direct security implications. Switch jump tables create indirect branches that can be exploited for Spectre v2 (branch target injection) attacks. Attackers can poison the branch target buffer (BTB) to redirect speculative execution to gadgets. Retpolines mitigate Spectre v2 but do not protect jump tables since they are implemented as indirect jumps via table lookup. By disabling jump tables under retpolines with -fno-jump-tables, the kernel forces conditional chains (if-else) instead of indirect jumps, eliminating this Spectre v2 attack surface from switch statements. This is a direct security improvement that ensures retpoline mitigations are effective across all code paths.

**CISB Status**
yes

---

## Digest JSON

```json
{
  "function_contexts": [
    {
      "file_path": "arch/x86/Makefile",
      "primary_symbol": "ifdef CONFIG_RETPOLINE",
      "changed_symbols": [
        "ifdef CONFIG_RETPOLINE"
      ],
      "why_it_matters": "This is the only file modified by the commit. It controls kernel compilation flags for x86, specifically the retpoline mitigation. The change ensures that switch jump tables are disabled under retpolines for older gcc versions, reducing indirect branch overhead.",
      "code_summary": "Inside the ifdef CONFIG_RETPOLINE block, the patch replaces the previous cc-option for --param=case-values-threshold=20 with a conditional addition of -fno-jump-tables when the compiler is not clang. This disables jump table generation entirely for gcc, aligning with clang's default behavior and newer gcc fixes."
    }
  ],
  "focused_contexts": [
    {
      "file_path": "arch/x86/Makefile",
      "reason": "This slice contains the entire modified block (lines 209-237) where the retpoline-related compiler flags are set. It is the core of the patch and necessary to understand the change from --param=case-values-threshold=20 to -fno-jump-tables.",
      "slice_content": "  209 endif\n  210 \n  211 # Workaround for a gcc prelease that unfortunately was shipped in a suse release\n  212 KBUILD_CFLAGS += -Wno-sign-compare\n  213 #\n  214 KBUILD_CFLAGS += -fno-asynchronous-unwind-tables\n  215 \n  216 # Avoid indirect branches in kernel to deal with Spectre\n  217 ifdef CONFIG_RETPOLINE\n  218   KBUILD_CFLAGS += $(RETPOLINE_CFLAGS)\n  219   # Additionally, avoid generating expensive indirect jumps which\n  220   # are subject to retpolines for small number of switch cases.\n  221   # clang turns off jump table generation by default when under\n  222   # retpoline builds, however, gcc does not for x86.\n  223   KBUILD_CFLAGS += $(call cc-option,--param=case-values-threshold=20)\n  224 endif\n  225 \n  226 archscripts: scripts_basic\n  227 \t$(Q)$(MAKE) $(build)=arch/x86/tools relocs\n  228 \n  229 ###\n  230 # Syscall table generation\n  231 \n  232 archheaders:\n  233 \t$(Q)$(MAKE) $(build)=arch/x86/entry/syscalls all\n  234 \n  235 ###\n  236 # Kernel objects\n  237 "
    }
  ]
}
```
