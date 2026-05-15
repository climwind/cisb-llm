# CISB Analysis Report

**Title**
Fix bogus delay loop in mach64_ct.c

**Issue**
CT based mach64 cards hang on sparc64 when compiled with gcc-4.1.x and later due to a bogus delay loop that gets optimized away.

**Tag**
compiler-optimization-bug

**Purpose**
Replace an empty for-loop delay with a real udelay() to ensure the delay is not optimized away by newer compilers, preventing crashes.

---

### Step-by-Step Analysis:
1. **Key Variables/Functionality**: The patch removes the unused variable 'i' and replaces the empty for-loop 'for (i=0;i<=0x1ffff;i++);' with a call to udelay(500) to ensure a proper delay when switching to sclk.
2. **Compiler Behavior**: gcc-4.0.x and earlier did not optimize away the empty for-loop, but gcc-4.1.x and later do, causing the delay to be eliminated.
3. **Pre/Post Compilation**: Compilation success: The code compiled successfully with both gcc-4.0.x and gcc-4.1.x+. The issue was not compilation failure but runtime behavior difference due to optimization.
4. **Security Implications**: The crash/hang on sparc64 represents a system availability issue (potential DoS). In kernel context, this has indirect security implications - system crashes affect integrity and availability.
---

1. [yes] Did compiler accept the kernel code and compile it successfully? The kernel code compiled successfully with both gcc-4.0.x and gcc-4.1.x+. The commit message indicates cards 'hang on sparc64 boxes when compiled with gcc-4.1.x and later' - this describes successful compilation followed by runtime failure, not compilation failure.
2. [yes] Is the commit describing a runtime bug caused by optimization or default compiler behavior? The commit explicitly describes a runtime bug caused by compiler optimization behavior. gcc-4.1.x and later optimized away the empty for-loop delay that gcc-4.0.x and earlier preserved.
3. [yes] Without that optimization or default behavior, would the problematic difference disappear? Without the gcc-4.1.x+ optimization that eliminated the empty for-loop, the problematic difference would disappear. Evidence shows gcc-4.0.x and earlier preserved the empty for-loop as a timing delay, and cards functioned correctly.
4. [yes] Did observable runtime behavior change after compilation? Observable runtime behavior clearly changed after compilation with different gcc versions. With gcc-4.0.x and earlier, the empty for-loop was preserved and provided actual timing delay, allowing CT-based mach64 cards to function correctly on sparc64.
5. [yes] Does the change have direct or indirect security implications in kernel context? The crash/hang on sparc64 systems represents an indirect security implication in kernel context. System crashes affect availability (potential DoS condition) and system integrity.

**CISB Status**
yes

---

## Digest JSON

```json
{
  "function_contexts": [
    {
      "file_path": "drivers/video/aty/mach64_ct.c",
      "primary_symbol": "static void aty_resume_pll_ct(const struct fb_info *info, union aty_pll *pll)",
      "changed_symbols": [
        "static void aty_resume_pll_ct(const struct fb_info *info, union aty_pll *pll)"
      ],
      "why_it_matters": "This function contains the critical delay that was previously implemented as an empty for-loop, which newer compilers optimize away, causing system crashes.",
      "code_summary": "The patch removes the unused variable 'i' and replaces the empty for-loop 'for (i=0;i<=0x1ffff;i++);' with a call to udelay(500) to ensure a proper delay when switching to sclk."
    }
  ],
  "focused_contexts": [
    {
      "file_path": "drivers/video/aty/mach64_ct.c",
      "reason": "Contains the exact code change: removal of the empty for-loop and addition of udelay(500).",
      "slice_content": "  595 static void aty_resume_pll_ct(const struct fb_info *info,\n  596 \t\t\t      union aty_pll *pll)\n  597 {\n  598 \tstruct atyfb_par *par = info->par;\n  599 \n  600 \tif (par->mclk_per != par->xclk_per) {\n  601 \t\tint i;\n  602 \t\t/*\n  603 \t\t* This disables the sclk, crashes the computer as reported:\n  604 \t\t* aty_st_pll_ct(SPLL_CNTL2, 3, info);\n  605 \t\t*\n  606 \t\t* So it seems the sclk must be enabled before it is used;\n  607 \t\t* so PLL_GEN_CNTL must be programmed *after* the sclk.\n  608 \t\t*/\n  609 \t\taty_st_pll_ct(SCLK_FB_DIV, pll->ct.sclk_fb_div, par);\n  610 \t\taty_st_pll_ct(SPLL_CNTL2, pll->ct.spll_cntl2, par);\n  611 \t\t/*\n  612 \t\t * The sclk has been started. However, I believe the first clock\n  613 \t\t * ticks it generates are not very stable. Hope this primitive loop\n  614 \t\t * helps for Rage Mobilities that sometimes crash when\n  615 \t\t * we switch to sclk. (Daniel Mantione, 13-05-2003)\n  616 \t\t */\n  617 \t\tfor (i=0;i<=0x1ffff;i++);\n  618 \t}\n  619 \n  620 \taty_st_pll_ct(PLL_REF_DIV, pll->ct.pll_ref_div, par);\n  621 \taty_st_pll_ct(PLL_GEN_CNTL, pll->ct.pll_gen_cntl, par);\n  622 \taty_st_pll_ct(MCLK_FB_DIV, pll->ct.mclk_fb_div, par);\n  623 \taty_st_pll_ct(PLL_EXT_CNTL, pll->ct.pll_ext_cntl, par);\n  624 \taty_st_pll_ct(EXT_VPLL_CNTL, pll->ct.ext_vpll_cntl, par);\n  625 }"
    }
  ]
}
```
