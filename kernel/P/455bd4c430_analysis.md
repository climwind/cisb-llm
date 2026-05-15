# CISB Analysis Report

**Title**
ARM memset Return Value Mismatch with GCC Optimization

**Issue**
ARM assembly memset implementation did not return the first argument in r0, causing corruption when GCC 4.7.2+ optimizations reused the return value.

**Tag**
compiler-optimization-conflict

**Purpose**
Ensure memset assembly returns the pointer argument in r0 to comply with C standard and compiler expectations.

---

### Step-by-Step Analysis:
1. **Key Variables/Functionality**: r0 holds the return pointer; ip used as base register for stores; r8 saved/restored to prevent corruption.
2. **Compiler Behavior**: GCC 4.7.2+ optimizes assuming memset returns the first argument in r0, reusing r0 after the call.
3. **Pre/Post Compilation**: Original assembly worked with older GCC; GCC 4.7.2+ optimization caused runtime crashes due to r0 mismatch.
4. **Security Implications**: Kernel mutex structure corruption leads to system crashes or potential privilege escalation.
---

1. [yes] Did compiler accept the kernel code and compile it successfully? The commit message indicates the code compiled successfully with GCC 4.7.2. The issue was runtime crashes, not compilation failures. The assembly code was accepted by the compiler and linked into the kernel.
2. [yes] Is the commit describing a runtime bug caused by optimization or default compiler behavior? The commit explicitly describes a runtime bug caused by GCC 4.7.2+ optimizations. The message states 'memset-related crashes caused by recent GCC (4.7.2) optimizations'. GCC assumed memset returns the pointer in r0 (standard C library convention), but the ARM assembly implementation did not preserve r0, causing register/memory corruption when the compiler reused the return value.
3. [yes] Without that optimization or default behavior, would the problematic difference disappear? Without GCC 4.7.2+'s optimization assumption that memset returns the pointer in r0, the compiler would not have reused r0 after the memset call. The original ARM assembly memset code worked correctly with older GCC versions that didn't make this assumption. The problematic difference (register/memory corruption) only appears when the optimization is applied, so removing that optimization would eliminate the bug.
4. [yes] Did observable runtime behavior change after compilation? Observable runtime behavior changed after compilation with GCC 4.7.2+. The commit message explicitly states 'memset-related crashes caused by recent GCC (4.7.2) optimizations'. The compiler assumed memset returns the pointer in r0 and reused that value after the call, but the ARM assembly implementation did not preserve r0, causing register/memory corruption that manifested as runtime crashes.
5. [yes] Does the change have direct or indirect security implications in kernel context? The memset corruption affects kernel mutex debugging structures in kernel space. Register/memory corruption at the kernel level can lead to privilege escalation, data corruption, or system crashes. This has direct security implications as it compromises kernel integrity and could potentially be exploited for privilege escalation or denial of service attacks. The commit message explicitly mentions 'crashes' which indicates observable security-relevant behavior changes.

**CISB Status**
yes

---

## Digest JSON

```json
{
  "function_contexts": [
    {
      "file_path": "arch/arm/lib/memset.S",
      "primary_symbol": "ENTRY(memset)",
      "changed_symbols": [
        "ENTRY(memset)"
      ],
      "why_it_matters": "This is the core function being patched. The fix ensures the function returns the pointer in r0, aligning with the C standard and preventing compiler-induced crashes.",
      "code_summary": "The patch modifies the memset assembly to save the original pointer (r0) into ip at entry, then uses ip as the base register for stores instead of r0. It also saves and restores r8 (previously used as a scratch register) to avoid corruption. The changes ensure that r0 remains unchanged throughout the function, thus returning the pointer."
    }
  ],
  "focused_contexts": [
    {
      "file_path": "arch/arm/lib/memset.S",
      "reason": "Contains the full diff context showing the alignment loop and the entry point, illustrating how r0 is replaced by ip and r8 is saved/restored.",
      "slice_content": "    4  *  Copyright (C) 1995-2000 Russell King\n    5  *\n    6  * This program is free software; you can redistribute it and/or modify\n    7  * it under the terms of the GNU General Public License version 2 as\n    8  * published by the Free Software Foundation.\n    9  *\n   10  *  ASM optimised string functions\n   11  */\n   12 #include <linux/linkage.h>\n   13 #include <asm/assembler.h>\n   14 \n   15 \t.text\n   16 \t.align\t5\n   17 \t.word\t0\n   18 \n   19 1:\tsubs\tr2, r2, #4\t\t@ 1 do we have enough\n   20 \tblt\t5f\t\t\t@ 1 bytes to align with?\n   21 \tcmp\tr3, #2\t\t\t@ 1\n   22 \tstrltb\tr1, [r0], #1\t\t@ 1\n   23 \tstrleb\tr1, [r0], #1\t\t@ 1\n   24 \tstrb\tr1, [r0], #1\t\t@ 1\n   25 \tadd\tr2, r2, r3\t\t@ 1 (r2 = r2 - (4 - r3))\n   26 /*\n   27  * The pointer is now aligned and the length is adjusted.  Try doing the\n   28  * memset again.\n   29  */\n   30 \n   31 ENTRY(memset)\n   32 \tands\tr3, r0, #3\t\t@ 1 unaligned?\n   33 \tbne\t1b\t\t\t@ 1\n   34 /*\n   35  * we know that the pointer in r0 is aligned to a word boundary.\n   36  */\n   37 \torr\tr1, r1, r1, lsl #8\n   38 \torr\tr1, r1, r1, lsl #16\n   39 \tmov\tr3, r1\n   40 \tcmp\tr2, #16\n   41 \tblt\t4f\n   42 \n   43 #if ! CALGN(1)+0\n   44 \n   45 /*\n   46  * We need an extra register for this loop - save the return address and\n   47  * use the LR\n   48  */\n   49 \tstr\tlr, [sp, #-4]!\n   50 \tmov\tip, r1\n   51 \tmov\tlr, r1\n   52 \n   53 2:\tsubs\tr2, r2, #64\n   54 \tstmgeia\tr0!, {r1, r3, ip, lr}\t@ 64 bytes at a time."
    },
    {
      "file_path": "arch/arm/lib/memset.S",
      "reason": "Shows the ENTRY(memset) function body, including the initial alignment check and the main loop setup, where the key changes (mov ip, r0 and register substitutions) are applied.",
      "slice_content": "   31 ENTRY(memset)\n   32 \tands\tr3, r0, #3\t\t@ 1 unaligned?\n   33 \tbne\t1b\t\t\t@ 1\n   34 /*\n   35  * we know that the pointer in r0 is aligned to a word boundary.\n   36  */\n   37 \torr\tr1, r1, r1, lsl #8\n   38 \torr\tr1, r1, r1, lsl #16\n   39 \tmov\tr3, r1\n   40 \tcmp\tr2, #16\n   41 \tblt\t4f\n   42 \n   43 #if ! CALGN(1)+0\n   44 \n   45 /*\n   46  * We need an extra register for this loop - save the return address and\n   47  * use the LR\n   48  */\n   49 \tstr\tlr, [sp, #-4]!\n   50 \tmov\tip, r1\n   51 \tmov\tlr, r1\n   52 \n   53 2:\tsubs\tr2, r2, #64\n   54 \tstmgeia\tr0!, {r1, r3, ip, lr}\t@ 64 bytes at a time."
    }
  ]
}
```
