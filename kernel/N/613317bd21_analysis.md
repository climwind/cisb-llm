# CISB Analysis Report

**Title**
EVM HMAC Timing Side Channel Fix

**Issue**
CVE-2016-2085: Timing side channel vulnerability in EVM HMAC verification allows MAC forgery

**Tag**
security/integrity/evm

**Purpose**
Replace memcmp() with crypto_memneq() in evm_verify_hmac() to prevent timing side channel attacks

---

### Step-by-Step Analysis:
1. **Key Variables/Functionality**: The function evm_verify_hmac() performs HMAC verification. The key change is replacing memcmp() with crypto_memneq() for digest comparison to ensure constant-time execution.
2. **Compiler Behavior**: No special compiler behavior involved. The vulnerability was not introduced by compiler optimization; crypto_memneq() is designed to be constant-time regardless of compiler flags.
3. **Pre/Post Compilation**: The fix is implemented at the source code level. The problematic timing behavior exists inherently in memcmp() regardless of compilation settings, requiring a source change to crypto_memneq().
4. **Security Implications**: Direct security impact. The vulnerability allowed MAC forgery with complexity reduced from 2^128 to 2^12. The fix eliminates the timing side channel, restoring security in the integrity measurement subsystem.
---

1. [yes] Did compiler accept the kernel code and compile it successfully? Commit 613317bd212c585c20796c10afe5daaa95d4b0a1 was successfully merged into the kernel tree in 2016, indicating the code compiled without errors.
2. [no] Is the commit describing a runtime bug caused by optimization or default compiler behavior? This is not a compiler-introduced bug. The vulnerability existed in the source code because the developer used memcmp() instead of a constant-time comparison function.
3. [no] Without that optimization or default behavior, would the problematic difference disappear? The timing side channel exists inherently in memcmp() regardless of compiler optimization. The problem does not disappear without optimization; it requires a source code change.
4. [yes] Did observable runtime behavior change after compilation? Observable runtime behavior changed in terms of timing characteristics. crypto_memneq() provides constant-time comparison versus memcmp()'s variable-time comparison.
5. [yes] Does the change have direct or indirect security implications in kernel context? Direct security implications confirmed (CVE-2016-2085). The fix prevents attackers from exploiting timing differences to forge MACs, improving kernel integrity security.

**CISB Status**
no

---

## Digest JSON

```json
{
  "function_contexts": [
    {
      "file_path": "security/integrity/evm/evm_main.c",
      "primary_symbol": "static enum integrity_status evm_verify_hmac(struct dentry *dentry,",
      "changed_symbols": [
        "static enum integrity_status evm_verify_hmac(struct dentry *dentry,"
      ],
      "why_it_matters": "This function performs HMAC verification for EVM; the memcmp() call was vulnerable to timing attacks, and replacing it with crypto_memneq() eliminates the side channel.",
      "code_summary": "Added #include <crypto/algapi.h> and replaced memcmp() with crypto_memneq() in the HMAC digest comparison inside evm_verify_hmac()."
    }
  ],
  "focused_contexts": [
    {
      "file_path": "security/integrity/evm/evm_main.c",
      "reason": "Contains the exact line where memcmp() is replaced with crypto_memneq(), which is the core of the fix.",
      "slice_content": "  126 \trc = vfs_getxattr_alloc(dentry, XATTR_NAME_EVM, (char **)&xattr_data, 0,\n  127 \t\t\t\tGFP_NOFS);\n  128 \tif (rc <= 0) {\n  129 \t\tevm_status = INTEGRITY_FAIL;\n  130 \t\tif (rc == -ENODATA) {\n  131 \t\t\trc = evm_find_protected_xattrs(dentry);\n  132 \t\t\tif (rc > 0)\n  133 \t\t\t\tevm_status = INTEGRITY_NOLABEL;\n  134 \t\t\telse if (rc == 0)\n  135 \t\t\t\tevm_status = INTEGRITY_NOXATTRS; /* new file */\n  136 \t\t} else if (rc == -EOPNOTSUPP) {\n  137 \t\t\tevm_status = INTEGRITY_UNKNOWN;\n  138 \t\t}\n  139 \t\tgoto out;\n  140 \t}"
    }
  ]
}
```
