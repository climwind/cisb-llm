# CISB Analysis Report

**Title**
PARISC Bootloader Panic due to gcc-7 Unaligned Access Optimization

**Issue**
gcc-7 optimizes byte-wise accesses of get_unaligned_le32() into word-wise accesses for external variables, causing unaligned access faults.

**Tag**
compiler-optimization

**Purpose**
Prevent gcc-7 from optimizing get_unaligned_le32() into word-wise accesses by declaring output_len as byte-aligned.

---

### Step-by-Step Analysis:
1. **Key Variables/Functionality**: output_len is accessed via get_unaligned_le32() relying on byte-wise access.
2. **Compiler Behavior**: gcc-7 converts byte-wise accesses to word-wise accesses for external 32-bit integers.
3. **Pre/Post Compilation**: Code compiles successfully but triggers unaligned access faults during boot.
4. **Security Implications**: Bootloader panic compromises boot integrity and causes denial-of-service.
---

1. [yes] Did compiler accept the kernel code and compile it successfully? The kernel code compiled successfully with gcc-7. The issue was not a compilation error but a runtime problem - the bootloader panicked due to unaligned access faults triggered by gcc-7's optimization behavior.
2. [yes] Is the commit describing a runtime bug caused by optimization or default compiler behavior? The commit explicitly describes a runtime bug caused by gcc-7's optimization behavior. gcc-7 optimizes byte-wise accesses of get_unaligned_le32() into word-wise accesses when output_len is declared as external.
3. [yes] Without that optimization or default behavior, would the problematic difference disappear? Without gcc-7's optimization that converts byte-wise accesses to word-wise accesses for external 32-bit integers, the unaligned access fault would not occur. The patch adds __aligned(1) to output_len which prevents this optimization.
4. [yes] Did observable runtime behavior change after compilation? The commit message explicitly states the bootloader panics due to unaligned access faults triggered by gcc-7's optimization. This represents a clear observable runtime behavior change.
5. [yes] Does the change have direct or indirect security implications in kernel context? The bootloader panic caused by unaligned access faults has indirect security implications in kernel context: Boot process integrity is compromised, representing a denial-of-service at boot time.

**CISB Status**
yes

---

## Digest JSON

```json
{
  "function_contexts": [
    {
      "file_path": "arch/parisc/boot/compressed/misc.c",
      "primary_symbol": "output_len",
      "changed_symbols": [
        "output_len"
      ],
      "why_it_matters": "output_len is accessed via get_unaligned_le32() which relies on byte-wise access; gcc-7's optimization to word-wise access causes unaligned memory access panic.",
      "code_summary": "Changed extern __le32 output_len to extern __le32 output_len __aligned(1) to force byte alignment and prevent gcc-7 from optimizing accesses to word-wise."
    },
    {
      "file_path": "arch/parisc/boot/compressed/Makefile",
      "primary_symbol": "KBUILD_CFLAGS",
      "changed_symbols": [
        "KBUILD_CFLAGS"
      ],
      "why_it_matters": "Adding -Os flag reduces code size and may avoid compiler optimizations that cause unaligned access issues.",
      "code_summary": "Added -Os to KBUILD_CFLAGS to compile boot code optimized for size."
    }
  ],
  "focused_contexts": [
    {
      "file_path": "arch/parisc/boot/compressed/misc.c",
      "reason": "Contains the declaration of output_len and the patch that adds __aligned(1) attribute.",
      "slice_content": "   14  */\n   15 #define STATIC static\n   16 \n   17 #undef memmove\n   18 #define memmove memmove\n   19 #define memzero(s, n) memset((s), 0, (n))\n   20 \n   21 #define malloc\tmalloc_gzip\n   22 #define free\tfree_gzip\n   23 \n   24 /* Symbols defined by linker scripts */\n   25 extern char input_data[];\n   26 extern int input_len;\n   27 extern __le32 output_len;\t/* at unaligned address, little-endian */\n   28 extern char _text, _end;\n   29 extern char _bss, _ebss;\n   30 extern char _startcode_end;\n   31 extern void startup_continue(void *entry, unsigned long cmdline,\n   32 \tunsigned long rd_start, unsigned long rd_end) __noreturn;\n   33 \n   34 void error(char *m) __noreturn;\n   35 \n   36 static unsigned long free_mem_ptr;\n   37 static unsigned long free_mem_end_ptr;\n   38 \n   39 #ifdef CONFIG_KERNEL_GZIP\n   40 #include \"../../../../lib/decompress_inflate.c\"\n   41 #endif"
    },
    {
      "file_path": "arch/parisc/boot/compressed/Makefile",
      "reason": "Contains the KBUILD_CFLAGS line where -Os is added.",
      "slice_content": "    5 #\n    6 \n    7 KCOV_INSTRUMENT := n\n    8 GCOV_PROFILE := n\n    9 UBSAN_SANITIZE := n\n   10 \n   11 targets := vmlinux.lds vmlinux vmlinux.bin vmlinux.bin.gz vmlinux.bin.bz2\n   12 targets += vmlinux.bin.xz vmlinux.bin.lzma vmlinux.bin.lzo vmlinux.bin.lz4\n   13 targets += misc.o piggy.o sizes.h head.o real2.o firmware.o\n   14 \n   15 KBUILD_CFLAGS := -D__KERNEL__ -O2 -DBOOTLOADER\n   16 KBUILD_CFLAGS += -DDISABLE_BRANCH_PROFILING\n   17 KBUILD_CFLAGS += $(cflags-y) -fno-delete-null-pointer-checks\n   18 KBUILD_CFLAGS += -fno-PIE -mno-space-regs -mdisable-fpregs\n   19 ifndef CONFIG_64BIT\n   20 KBUILD_CFLAGS += -mfast-indirect-calls\n   21 endif\n   22 \n   23 OBJECTS += $(obj)/head.o $(obj)/real2.o $(obj)/firmware.o $(obj)/misc.o $(obj)/piggy.o\n   24 \n   25 # LDFLAGS_vmlinux := -X --whole-archive -e startup -T\n   26 LDFLAGS_vmlinux := -X -e startup --as-needed -T\n   27 $(obj)/vmlinux: $(obj)/vmlinux.lds $(OBJECTS) $(LIBGCC)\n   28 \t$(call if_changed,ld)\n   29 \n   30 sed-sizes := -e 's/^\\([0-9a-fA-F]*\\) . \\(__bss_start\\|_end\\|parisc_kernel_start\\)$$/\\#define SZ\\2 0x\\1/p'\n   31 \n   32 quiet_cmd_sizes = GEN $@"
    }
  ]
}
```
