# CISB Analysis Report

**Title**
x86/mm: Use WRITE_ONCE() when setting PTEs

**Issue**
Compiler may optimize PTE assignments into multiple writes, creating a window where an interim non-present PTE could be exploited (e.g., L1TF).

**Tag**
CISB

**Purpose**
Use WRITE_ONCE() when setting PTEs and related page table entries to prevent compiler from splitting the write into multiple instructions, ensuring atomicity and closing a potential security hole.

---

### Step-by-Step Analysis:
1. **Key Variables/Functionality**: Page table entries (PTEs, PMDs, PUDs, PGDs) are modified by functions like pmdp_establish(), native_set_pte(), and set_access_flags(). These entries control memory mapping and permissions.
2. **Compiler Behavior**: Compiler may optimize PTE assignments into multiple store instructions without WRITE_ONCE(). WRITE_ONCE() forces a single store instruction or equivalent atomic sequence.
3. **Pre/Post Compilation**: Pre-patch: Compiler could split writes, creating interim non-present PTE state. Post-patch: WRITE_ONCE() ensures atomic writes, eliminating the transient vulnerable state.
4. **Security Implications**: Interim non-present PTEs could be exploited via L1TF to access protected memory. The fix prevents this transient state, securing kernel memory isolation.
---

1. [yes] Did compiler accept the kernel code and compile it successfully? The commit was successfully merged into the kernel (commit hash 9bc4f28af75a91aea0ae383f50b0a430c4509303 from 2018). The commit message states the author 'skimmed the differences in the binary with and without this patch', which confirms the code compiled successfully both with and without the WRITE_ONCE() changes. The patch was accepted and integrated into the kernel tree.
2. [yes] Is the commit describing a runtime bug caused by optimization or default compiler behavior? The commit message explicitly states 'the compiler might optimize their assignment by using multiple instructions to set the PTE' which creates an interim non-present PTE that could be exploited (e.g., L1TF). This is a runtime bug caused by compiler optimization behavior, not a source code logic error. The WRITE_ONCE() fix prevents the compiler from splitting the write into multiple instructions.
3. [yes] Without that optimization or default behavior, would the problematic difference disappear? Without the compiler optimization that splits PTE writes into multiple instructions, the problematic interim non-present PTE state would not occur. The vulnerability exists specifically because the compiler may emit multiple store instructions for a single assignment. If the compiler did not perform this optimization (or if WRITE_ONCE() prevents it), the write would be atomic and the security window would disappear.
4. [yes] Did observable runtime behavior change after compilation? The commit message explicitly states binary differences exist between the patched and unpatched versions (greater when CONFIG_PARAVIRT=n). The WRITE_ONCE() change prevents the compiler from emitting multiple store instructions for PTE assignments, eliminating the interim non-present PTE state that could be observed at runtime. This represents a measurable change in observable runtime behavior - the transient vulnerable window no longer exists after compilation with the fix.
5. [yes] Does the change have direct or indirect security implications in kernel context? The commit explicitly addresses L1TF vulnerability - a hardware security issue where interim non-present PTEs could be exploited. Page table entries control memory access permissions in the kernel. If an attacker can observe or exploit the transient non-present state during a multi-write PTE update, they could potentially access protected memory. This has direct security implications for kernel memory isolation and protection mechanisms. The WRITE_ONCE() fix closes this security window by ensuring atomic PTE writes.

**CISB Status**
yes

---

## Digest JSON

```json
{
  "function_contexts": [
    {
      "file_path": "arch/x86/include/asm/pgtable.h",
      "primary_symbol": "static inline pmd_t pmdp_establish(struct vm_area_struct *vma,",
      "changed_symbols": [
        "static inline pmd_t pmdp_establish(struct vm_area_struct *vma,"
      ],
      "why_it_matters": "pmdp_establish() is used to atomically set a PMD entry. The old code used a plain assignment, which could be non-atomic. WRITE_ONCE() ensures the write is not torn.",
      "code_summary": "Changed '*pmdp = pmd' to 'WRITE_ONCE(*pmdp, pmd)' in the non-xchg path of pmdp_establish()."
    },
    {
      "file_path": "arch/x86/include/asm/pgtable_64.h",
      "primary_symbol": "struct mm_struct;",
      "changed_symbols": [
        "struct mm_struct;",
        "static inline void native_set_pte_atomic(pte_t *ptep, pte_t pte)",
        "static inline pmd_t native_pmdp_get_and_clear(pmd_t *xp)",
        "static inline void native_set_p4d(p4d_t *p4dp, p4d_t p4d)",
        "static inline void native_p4d_clear(p4d_t *p4d)"
      ],
      "why_it_matters": "These native functions are the low-level primitives for setting/clearing page table entries. Without WRITE_ONCE(), they could be compiled into multiple writes, creating security holes.",
      "code_summary": "Replaced plain assignments with WRITE_ONCE() in native_set_pte(), native_set_pmd(), native_set_pud(), native_set_p4d(), native_set_pgd(), native_pte_clear(), native_pmd_clear(), native_pud_clear(), native_p4d_clear(), native_pgd_clear(), native_set_pte_atomic(), native_pmdp_get_and_clear(), native_pudp_get_and_clear(), native_set_p4d(), native_p4d_clear()."
    },
    {
      "file_path": "arch/x86/mm/pgtable.c",
      "primary_symbol": "static void mop_up_one_pmd(struct mm_struct *mm, pgd_t *pgdp)",
      "changed_symbols": [
        "static void mop_up_one_pmd(struct mm_struct *mm, pgd_t *pgdp)",
        "int ptep_set_access_flags(struct vm_area_struct *vma,",
        "int pmdp_set_access_flags(struct vm_area_struct *vma,",
        "int pudp_set_access_flags(struct vm_area_struct *vma, unsigned long address,"
      ],
      "why_it_matters": "These functions modify page table entries during page table teardown and access flag updates. Using WRITE_ONCE() ensures the writes are atomic and prevents intermediate states.",
      "code_summary": "Changed '*pgdp = native_make_pgd(0)' to 'pgd_clear(pgdp)' in mop_up_one_pmd(). Changed '*ptep = entry' to 'set_pte_at(mm, address, ptep, entry)' in ptep_set_access_flags(). Changed '*pmdp = entry' to 'set_pmd_at(mm, address, pmdp, entry)' in pmdp_set_access_flags(). Changed '*pudp = entry' to 'set_pud(pudp, entry)' in pudp_set_access_flags()."
    }
  ],
  "focused_contexts": [
    {
      "file_path": "arch/x86/include/asm/pgtable_64.h",
      "reason": "Contains the core native_set_* and native_*_clear functions that are the primary targets of the WRITE_ONCE() conversion.",
      "slice_content": "   45 \tpr_err(\"%s:%d: bad p4d %p(%016lx)\\n\",\t\t\\\n   46 \t       __FILE__, __LINE__, &(e), p4d_val(e))\n   47 #endif\n   48 \n   49 #define pgd_ERROR(e)\t\t\t\t\t\\\n   50 \tpr_err(\"%s:%d: bad pgd %p(%016lx)\\n\",\t\t\\\n   51 \t       __FILE__, __LINE__, &(e), pgd_val(e))\n   52 \n   53 struct mm_struct;\n   54 \n   55 void set_pte_vaddr_p4d(p4d_t *p4d_page, unsigned long vaddr, pte_t new_pte);\n   56 void set_pte_vaddr_pud(pud_t *pud_page, unsigned long vaddr, pte_t new_pte);\n   57 \n   58 static inline void native_pte_clear(struct mm_struct *mm, unsigned long addr,\n   59 \t\t\t\t    pte_t *ptep)\n   60 {\n   61 \t*ptep = native_make_pte(0);\n   62 }"
    },
    {
      "file_path": "arch/x86/include/asm/pgtable.h",
      "reason": "Contains pmdp_establish() which is a key function for setting PMDs atomically.",
      "slice_content": " 1184 static inline int pud_write(pud_t pud)\n 1185 {\n 1186 \treturn pud_flags(pud) & _PAGE_RW;\n 1187 }"
    },
    {
      "file_path": "arch/x86/mm/pgtable.c",
      "reason": "Contains mop_up_one_pmd() and the set_access_flags functions that are modified to use WRITE_ONCE() via helper functions.",
      "slice_content": "  228 static int preallocate_pmds(struct mm_struct *mm, pmd_t *pmds[], int count)\n  229 {\n  230 \tint i;\n  231 \tbool failed = false;\n  232 \tgfp_t gfp = PGALLOC_GFP;\n  233 \n  234 \tif (mm == &init_mm)\n  235 \t\tgfp &= ~__GFP_ACCOUNT;\n  236 \n  237 \tfor (i = 0; i < count; i++) {\n  238 \t\tpmd_t *pmd = (pmd_t *)__get_free_page(gfp);\n  239 \t\tif (!pmd)\n  240 \t\t\tfailed = true;\n  241 \t\tif (pmd && !pgtable_pmd_page_ctor(virt_to_page(pmd))) {\n  242 \t\t\tfree_page((unsigned long)pmd);\n  243 \t\t\tpmd = NULL;\n  244 \t\t\tfailed = true;\n  245 \t\t}\n  246 \t\tif (pmd)\n  247 \t\t\tmm_inc_nr_pmds(mm);\n  248 \t\tpmds[i] = pmd;\n  249 \t}\n  250 \n  251 \tif (failed) {\n  252 \t\tfree_pmds(mm, pmds, count);\n  253 \t\treturn -ENOMEM;\n  254 \t}\n  255 \n  256 \treturn 0;\n  257 }"
    }
  ]
}
```
