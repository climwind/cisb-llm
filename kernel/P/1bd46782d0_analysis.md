# CISB Analysis Report

**Title**
ARM: avoid unwanted GCC memset()/memcpy() optimisations for IO variants

**Issue**
GCC optimizes memset_io(), memcpy_fromio(), and memcpy_toio() by replacing them with standard memset()/memcpy(), introducing unaligned accesses invalid for device mappings.

**Tag**
compiler-optimization

**Purpose**
Prevent GCC from optimizing IO memory access functions by using separate assembly symbols (mmioset, mmiocpy) instead of standard memset/memcpy.

---

### Step-by-Step Analysis:
1. **Key Variables/Functionality**: Functions memset_io, memcpy_fromio, memcpy_toio are used for IO memory access. The patch introduces mmioset and mmiocpy as separate assembly symbols to bypass compiler optimization.
2. **Compiler Behavior**: GCC replaces calls to memset/memcpy with optimized versions that assume aligned memory, causing unaligned accesses on IO memory.
3. **Pre/Post Compilation**: Before patch, GCC optimized IO functions leading to unaligned accesses. After patch, separate symbols prevent optimization, ensuring assembly implementation is used directly.
4. **Security Implications**: Unaligned accesses on device mappings can cause hardware faults, system crashes, or data corruption, leading to potential DoS or privilege escalation.
---

1. [yes] Did compiler accept the kernel code and compile it successfully? The commit was successfully merged into the Linux kernel (commit hash 1bd46782d08b01b73df0085b51ea1021b19b44fd from 2015), which indicates the compiler accepted and compiled the code successfully. The patch adds new symbols (mmioset, mmiocpy) with proper extern declarations in io.h, exports in armksyms.c, and assembly implementations in memset.S, all of which are standard kernel build patterns that compile without errors.
2. [yes] Is the commit describing a runtime bug caused by optimization or default compiler behavior? The commit message explicitly states 'GCCs optimisation may introduce unaligned accesses which are invalid for device mappings.' This describes a runtime bug caused by GCC's default optimization behavior where it replaces calls to memset/memcpy with optimized versions that assume aligned memory, violating IO memory access constraints.
3. [yes] Without that optimization or default behavior, would the problematic difference disappear? Without GCC's optimization behavior that replaces memset/memcpy calls with optimized versions assuming aligned memory, the problematic unaligned accesses would disappear. The patch uses separate assembly symbols (mmioset/mmiocpy) that GCC doesn't recognize for optimization, ensuring the original assembly implementation is used directly without transformation.
4. [yes] Did observable runtime behavior change after compilation? The commit message explicitly states 'GCCs optimisation may introduce unaligned accesses which are invalid for device mappings.' This confirms observable runtime behavior changed after compilation - GCC's optimization replaced memset/memcpy calls with optimized versions that perform unaligned memory accesses on IO memory, which would not occur with the original assembly implementation. The patch prevents this behavioral divergence by using separate symbol names (mmioset/mmiocpy) that GCC doesn't recognize for optimization.
5. [yes] Does the change have direct or indirect security implications in kernel context? The change has direct security implications in kernel context. Unaligned accesses on device mappings can cause hardware faults, system crashes, or data corruption. In the kernel, this could lead to denial of service if the system crashes, or potential privilege escalation if device memory handling is compromised. The commit explicitly prevents GCC optimizations that violate IO memory access constraints, making this a security-relevant fix that protects against compiler-introduced behavioral changes that could compromise system stability and security.

**CISB Status**
yes

---

## Digest JSON

```json
{
  "function_contexts": [
    {
      "file_path": "arch/arm/include/asm/io.h",
      "primary_symbol": "memset_io",
      "changed_symbols": [
        "memset_io",
        "memcpy_fromio",
        "memcpy_toio"
      ],
      "why_it_matters": "These inline functions are used for IO memory access; calling standard memset/memcpy allows GCC to optimize them, potentially causing unaligned accesses on device memory.",
      "code_summary": "Changed memset_io, memcpy_fromio, memcpy_toio to call mmioset/mmiocpy instead of memset/memcpy, with extern declarations for the new symbols."
    },
    {
      "file_path": "arch/arm/kernel/armksyms.c",
      "primary_symbol": "mmioset",
      "changed_symbols": [
        "mmioset",
        "mmiocpy"
      ],
      "why_it_matters": "Exports the new mmioset and mmiocpy symbols so they are available to modules; also adds extern declarations for them.",
      "code_summary": "Added extern declarations for mmioset and mmiocpy, and exported them with EXPORT_SYMBOL."
    },
    {
      "file_path": "arch/arm/lib/memset.S",
      "primary_symbol": "mmioset",
      "changed_symbols": [
        "mmioset"
      ],
      "why_it_matters": "Provides the assembly implementation of mmioset as an alias to memset, ensuring no GCC optimization occurs.",
      "code_summary": "Added ENTRY(mmioset) before ENTRY(memset) and ENDPROC(mmioset) after ENDPROC(memset), making mmioset an alias for the same assembly code."
    }
  ],
  "focused_contexts": [
    {
      "file_path": "arch/arm/include/asm/io.h",
      "reason": "Shows the extern declaration of _memset_io and the patch context where memset_io is changed to call mmioset.",
      "slice_content": "  305 #define writel(v,c)\t\t({ __iowmb(); writel_relaxed(v,c); })"
    },
    {
      "file_path": "arch/arm/kernel/armksyms.c",
      "reason": "Shows the extern declarations area where mmioset and mmiocpy are added.",
      "slice_content": "   40 \n   41 extern void __aeabi_idiv(void);\n   42 extern void __aeabi_idivmod(void);\n   43 extern void __aeabi_lasr(void);\n   44 extern void __aeabi_llsl(void);\n   45 extern void __aeabi_llsr(void);\n   46 extern void __aeabi_lmul(void);\n   47 extern void __aeabi_uidiv(void);\n   48 extern void __aeabi_uidivmod(void);\n   49 extern void __aeabi_ulcmp(void);\n   50 \n   51 extern void fpundefinstr(void);\n   52 \n   53 \t/* platform dependent support */\n   54 EXPORT_SYMBOL(arm_delay_ops);\n   55 \n   56 \t/* networking */\n   57 EXPORT_SYMBOL(csum_partial);\n   58 EXPORT_SYMBOL(csum_partial_copy_from_user);\n   59 EXPORT_SYMBOL(csum_partial_copy_nocheck);\n   60 EXPORT_SYMBOL(__csum_ipv6_magic);\n   61 \n   62 \t/* io */\n   63 #ifndef __raw_readsb\n   64 EXPORT_SYMBOL(__raw_readsb);\n   65 #endif\n   66 #ifndef __raw_readsw"
    },
    {
      "file_path": "arch/arm/kernel/armksyms.c",
      "reason": "Shows the EXPORT_SYMBOL section where mmioset and mmiocpy exports are added.",
      "slice_content": "   78 #ifndef __raw_writesl\n   79 EXPORT_SYMBOL(__raw_writesl);\n   80 #endif\n   81 \n   82 \t/* string / mem functions */\n   83 EXPORT_SYMBOL(strchr);\n   84 EXPORT_SYMBOL(strrchr);\n   85 EXPORT_SYMBOL(memset);\n   86 EXPORT_SYMBOL(memcpy);\n   87 EXPORT_SYMBOL(memmove);\n   88 EXPORT_SYMBOL(memchr);\n   89 EXPORT_SYMBOL(__memzero);\n   90 \n   91 #ifdef CONFIG_MMU\n   92 EXPORT_SYMBOL(copy_page);\n   93 \n   94 EXPORT_SYMBOL(__copy_from_user);\n   95 EXPORT_SYMBOL(__copy_to_user);\n   96 EXPORT_SYMBOL(__clear_user);\n   97 \n   98 EXPORT_SYMBOL(__get_user_1);\n   99 EXPORT_SYMBOL(__get_user_2);\n  100 EXPORT_SYMBOL(__get_user_4);\n  101 EXPORT_SYMBOL(__get_user_8);\n  102 \n  103 #ifdef __ARMEB__\n  104 EXPORT_SYMBOL(__get_user_64t_1);"
    },
    {
      "file_path": "arch/arm/lib/memset.S",
      "reason": "Shows the ENTRY(mmioset) addition before ENTRY(memset).",
      "slice_content": "    4  *  Copyright (C) 1995-2000 Russell King\n    5  *\n    6  * This program is free software; you can redistribute it and/or modify\n    7  * it under the terms of the GNU General Public License version 2 as\n    8  * published by the Free Software Foundation.\n    9  *\n   10  *  ASM optimised string functions\n   11  */\n   12 #include <linux/linkage.h>\n   13 #include <asm/assembler.h>\n   14 #include <asm/unwind.h>\n   15 \n   16 \t.text\n   17 \t.align\t5\n   18 \n   19 ENTRY(memset)\n   20 UNWIND( .fnstart         )\n   21 \tands\tr3, r0, #3\t\t@ 1 unaligned?\n   22 \tmov\tip, r0\t\t\t@ preserve r0 as return value\n   23 \tbne\t6f\t\t\t@ 1\n   24 /*\n   25  * we know that the pointer in ip is aligned to a word boundary.\n   26  */\n   27 1:\torr\tr1, r1, r1, lsl #8\n   28 \torr\tr1, r1, r1, lsl #16\n   29 \tmov\tr3, r1\n   30 \tcmp\tr2, #16\n   31 \tblt\t4f\n   32 \n   33 #if ! CALGN(1)+0\n   34 \n   35 /*\n   36  * We need 2 extra registers for this loop - use r8 and the LR\n   37  */\n   38 \tstmfd\tsp!, {r8, lr}"
    },
    {
      "file_path": "arch/arm/lib/memset.S",
      "reason": "Shows the ENDPROC(mmioset) addition after ENDPROC(memset).",
      "slice_content": "  110 UNWIND( .fnstart            )\n  111 4:\ttst\tr2, #8\n  112 \tstmneia\tip!, {r1, r3}"
    }
  ]
}
```
