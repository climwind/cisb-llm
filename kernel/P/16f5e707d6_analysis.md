# CISB Analysis Report

**Title**
mm/rmap: stop store reordering issue on page->mapping

**Issue**
Store reordering may cause CPU1 to observe page->mapping without the PAGE_MAPPING_ANON bit after seeing PageLRU set, leading to crashes or data corruption.

**Tag**
CISB-Concurrency

**Purpose**
Prevent compiler from tearing the store to page->mapping by using WRITE_ONCE, ensuring the anon_vma pointer and PAGE_MAPPING_ANON bit are stored atomically.

---

### Step-by-Step Analysis:
1. **Key Variables/Functionality**: page->mapping stores the anon_vma pointer combined with the PAGE_MAPPING_ANON flag for anonymous pages.
2. **Compiler Behavior**: The compiler is allowed to split the store of (anon_vma + PAGE_MAPPING_ANON) into two separate stores, potentially leaving page->mapping with an anon_vma pointer missing the PAGE_MAPPING_ANON bit.
3. **Pre/Post Compilation**: Code compiles successfully both before and after the fix. The difference is runtime behavior: without WRITE_ONCE, store tearing allows race conditions; with WRITE_ONCE, stores are atomic.
4. **Security Implications**: Data corruption in kernel memory management can lead to crashes, system instability, privilege escalation, or information leakage via misinterpreted page mappings.
---

1. [yes] Did compiler accept the kernel code and compile it successfully? The commit was merged into the kernel in 2020, indicating the code compiled successfully. The issue is about runtime behavior (store reordering/tearing), not a compilation failure.
2. [yes] Is the commit describing a runtime bug caused by optimization or default compiler behavior? The commit explicitly describes a runtime bug caused by the compiler's default behavior - store tearing. The compiler is allowed to split the store of (anon_vma + PAGE_MAPPING_ANON) into two separate stores.
3. [yes] Without that optimization or default behavior, would the problematic difference disappear? Without the compiler's default store-tearing behavior, the problematic difference would disappear. WRITE_ONCE prevents this by ensuring atomic store, confirming the issue is directly tied to compiler's default store behavior.
4. [yes] Did observable runtime behavior change after compilation? Observable runtime behavior changes after compilation. Without WRITE_ONCE, the compiler can tear the store to page->mapping, allowing CPU1 to observe page->mapping without the PAGE_MAPPING_ANON bit after seeing PageLRU set.
5. [yes] Does the change have direct or indirect security implications in kernel context? The store reordering issue has direct security implications in kernel context. The digest explicitly states the bug can lead to 'crashes and data corruption', potentially enabling privilege escalation or DoS.

**CISB Status**
yes

---

## Digest JSON

```json
{
  "function_contexts": [
    {
      "file_path": "mm/rmap.c",
      "primary_symbol": "static void __page_set_anon_rmap(struct page *page,",
      "changed_symbols": [
        "static void __page_set_anon_rmap(struct page *page,"
      ],
      "why_it_matters": "This function sets page->mapping for anonymous pages. Without WRITE_ONCE, the store can be reordered, causing lockless rmap walkers (e.g., page_idle) to misinterpret the mapping.",
      "code_summary": "In __page_set_anon_rmap, the assignment page->mapping = (struct address_space *) anon_vma is replaced with WRITE_ONCE(page->mapping, (struct address_space *) anon_vma) to prevent compiler store tearing."
    }
  ],
  "focused_contexts": [
    {
      "file_path": "mm/rmap.c",
      "reason": "Contains the exact code change: replacing a plain store with WRITE_ONCE to fix the store reordering issue.",
      "slice_content": " 1039 static void __page_set_anon_rmap(struct page *page,\n 1040 \tstruct vm_area_struct *vma, unsigned long address, int exclusive)\n 1041 {\n 1042 \tstruct anon_vma *anon_vma = vma->anon_vma;\n 1043 \n 1044 \tBUG_ON(!anon_vma);\n 1045 \n 1046 \tif (PageAnon(page))\n 1047 \t\treturn;\n 1048 \n 1049 \t/*\n 1050 \t * If the page isn't exclusively mapped into this vma,\n 1051 \t * we must use the _oldest_ possible anon_vma for the\n 1052 \t * page mapping!\n 1053 \t */\n 1054 \tif (!exclusive)\n 1055 \t\tanon_vma = anon_vma->root;\n 1056 \n 1057 \tanon_vma = (void *) anon_vma + PAGE_MAPPING_ANON;\n 1058 \tpage->mapping = (struct address_space *) anon_vma;\n 1059 \tpage->index = linear_page_index(vma, address);\n 1060 }"
    }
  ]
}
```
