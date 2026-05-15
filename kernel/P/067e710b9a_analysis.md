# CISB Analysis Report

**Title**
ARM: 7801/1: v6: prevent gcc 4.5 from reordering extended CP15 reads above is_smp() test

**Issue**
GCC 4.5 reorders extended CP15 read above is_smp() test causing undefined instruction abort on ARM1136 r0 cores

**Tag**
compiler-reordering

**Purpose**
Prevent gcc 4.5 from reordering extended CP15 reads above is_smp() test to avoid boot failure

---

### Step-by-Step Analysis:
1. **Key Variables/Functionality**: read_cpuid_ext macro performs extended CP15 read used in cache_ops_need_broadcast()
2. **Compiler Behavior**: gcc 4.5 reorders the extended CP15 read (mrc instruction) before the is_smp() test
3. **Pre/Post Compilation**: Code compiles successfully but fails at runtime (boot) due to undefined instruction abort
4. **Security Implications**: Denial of service via boot failure on affected hardware compromises system availability
---

1. [yes] Did compiler accept the kernel code and compile it successfully? The kernel code compiled successfully with gcc 4.5. The commit message indicates the issue is a runtime bug (undefined instruction abort during boot), not a compilation failure. The code was accepted by the compiler and the problem only manifests at runtime when the reordered CP15 read executes on ARM1136 r0 cores.
2. [yes] Is the commit describing a runtime bug caused by optimization or default compiler behavior? The commit message explicitly states 'gcc 4.5 reorders the extended CP15 read above the is_smp() test' which causes undefined instruction aborts on ARM1136 r0 cores. This is a runtime bug directly caused by gcc 4.5's default optimization/reordering behavior, not a syntax or compilation error. The patch adds 'memory' clobber to prevent this reordering.
3. [yes] Without that optimization or default behavior, would the problematic difference disappear? Without gcc 4.5's reordering optimization, the is_smp() test would execute first and properly guard the CP15 read. The problematic difference (undefined instruction abort on ARM1136 r0 cores) would disappear because the extended CP15 read would only execute on cores that support those registers. The patch adds 'memory' clobber to prevent reordering, restoring the intended execution order.
4. [yes] Did observable runtime behavior change after compilation? The commit message explicitly states the previous commit 'breaks the boot on OMAP2430SDP' with 'undefined instruction abort from the CP15 read'. This is a clear observable runtime behavior change - the system fails to boot on ARM1136 r0 cores when gcc 4.5 reorders the CP15 read before the is_smp() test. After the patch adds the 'memory' clobber, boot succeeds because the CP15 read is properly guarded by the is_smp() test. The observable difference is boot failure vs. successful boot on affected hardware.
5. [yes] Does the change have direct or indirect security implications in kernel context? The bug causes undefined instruction aborts leading to boot failure on ARM1136 r0 cores. This represents a denial of service vulnerability where affected systems cannot boot. In kernel context, system availability is a security concern. While not directly exploitable for privilege escalation or code execution, the compiler-induced reordering creates indirect security implications by compromising system reliability and availability on affected hardware. The fix ensures proper execution ordering to prevent crashes.

**CISB Status**
yes

---

## Digest JSON

```json
{
  "function_contexts": [
    {
      "file_path": "arch/arm/include/asm/cputype.h",
      "primary_symbol": "read_cpuid_ext",
      "changed_symbols": [
        "read_cpuid_ext"
      ],
      "why_it_matters": "This macro performs an extended CP15 read that is used in cache_ops_need_broadcast(). The reordering by gcc 4.5 causes undefined instruction aborts on ARM1136 r0.",
      "code_summary": "The inline assembly for read_cpuid_ext is modified: the clobber list is changed from \"cc\" to \"memory\". This prevents the compiler from reordering the mrc instruction before any is_smp() test, ensuring it only executes on cores that support the extended CP15 registers."
    }
  ],
  "focused_contexts": [
    {
      "file_path": "arch/arm/include/asm/cputype.h",
      "reason": "Contains the definition of read_cpuid_ext macro and the patch that changes the clobber from 'cc' to 'memory'.",
      "slice_content": "   58 #define MPIDR_AFFINITY_LEVEL(mpidr, level) \\\n   59 \t((mpidr >> (MPIDR_LEVEL_BITS * level)) & MPIDR_LEVEL_MASK)\n   60 \n   61 #define ARM_CPU_IMP_ARM\t\t\t0x41\n   62 #define ARM_CPU_IMP_INTEL\t\t0x69\n   63 \n   64 #define ARM_CPU_PART_ARM1136\t\t0xB360\n   65 #define ARM_CPU_PART_ARM1156\t\t0xB560\n   66 #define ARM_CPU_PART_ARM1176\t\t0xB760\n   67 #define ARM_CPU_PART_ARM11MPCORE\t0xB020\n   68 #define ARM_CPU_PART_CORTEX_A8\t\t0xC080\n   69 #define ARM_CPU_PART_CORTEX_A9\t\t0xC090\n   70 #define ARM_CPU_PART_CORTEX_A5\t\t0xC050\n   71 #define ARM_CPU_PART_CORTEX_A15\t\t0xC0F0\n   72 #define ARM_CPU_PART_CORTEX_A7\t\t0xC070\n   73 \n   74 #define ARM_CPU_XSCALE_ARCH_MASK\t0xe000\n   75 #define ARM_CPU_XSCALE_ARCH_V1\t\t0x2000\n   76 #define ARM_CPU_XSCALE_ARCH_V2\t\t0x4000\n   77 #define ARM_CPU_XSCALE_ARCH_V3\t\t0x6000\n   78 \n   79 extern unsigned int processor_id;\n   80 \n   81 #ifdef CONFIG_CPU_CP15\n   82 #define read_cpuid(reg)\t\t\t\t\t\t\t\\\n   83 \t({\t\t\t\t\t\t\t\t\\\n   84 \t\tunsigned int __val;\t\t\t\t\t\\\n   85 \t\tasm(\"mrc\tp15, 0, %0, c0, c0, \" __stringify(reg)\t\\\n   86 \t\t    : \"=r\" (__val)\t\t\t\t\t\\\n   87 \t\t    :\t\t\t\t\t\t\t\\\n   88 \t\t    : \"cc\");\t\t\t\t\t\t\\\n   89 \t\t__val;\t\t\t\t\t\t\t\\\n   90 \t})"
    }
  ]
}
```
