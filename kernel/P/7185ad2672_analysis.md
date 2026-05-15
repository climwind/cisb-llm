# CISB Analysis Report

**Title**
GCC Optimization Removes Sensitive Data Clearing in Crypto Subsystem

**Issue**
GCC optimizes away memset() calls on stack variables going out of scope, leaving cryptographic keys and intermediate states uncleared in memory.

**Tag**
compiler-optimization-security

**Purpose**
Replace memset() with memzero_explicit() to prevent compiler optimization from removing sensitive data clearing operations.

---

### Step-by-Step Analysis:
1. **Key Variables/Functionality**: Intermediate buffers (W, D) in SHA256, Tiger, and Whirlpool algorithms hold sensitive hash states before truncation or finalization.
2. **Compiler Behavior**: GCC detects stack variables are unused after memset() and going out of scope, optimizing away the clearing instruction.
3. **Pre/Post Compilation**: Source code specifies memory clearing via memset(), but compiled binary omits these instructions due to optimization passes.
4. **Security Implications**: Uncleared sensitive data remains in stack memory, potentially accessible via memory dumps, side-channel attacks, or after process termination.
---

1. [yes] Did compiler accept the kernel code and compile it successfully? The commit was successfully merged into the 2014 kernel tree. The issue is not about compilation failure but about runtime behavior where GCC optimizes away memset() calls. The code compiled successfully with the unintended optimization behavior.
2. [yes] Is the commit describing a runtime bug caused by optimization or default compiler behavior? The commit explicitly describes a runtime bug where GCC optimizes away memset() calls on stack variables that are going out of scope. This is caused by compiler optimization behavior, not a source code logic error. The sensitive data clearing fails at runtime due to this optimization.
3. [yes] Without that optimization or default behavior, would the problematic difference disappear? Without GCC's optimization that removes memset() calls on variables going out of scope, the sensitive data clearing would work as intended. The problematic difference (uncleared sensitive crypto data in W, D buffers) would disappear if the compiler did not perform this optimization. memzero_explicit() was specifically designed to prevent this optimization.
4. [yes] Did observable runtime behavior change after compilation? Observable runtime behavior changed after compilation: GCC optimization removes memset() calls on stack variables going out of scope, causing sensitive crypto data (intermediate hash states in W, D buffers) to remain in memory instead of being cleared as intended by the source code.
5. [yes] Does the change have direct or indirect security implications in kernel context? Direct security implications exist: uncleared sensitive cryptographic data (keys, intermediate hash states in W, D buffers) remaining in memory after compiler optimization could be extracted by attackers through memory dumps, side-channel attacks, or after process termination. This compromises cryptographic security guarantees in the kernel, which is why memzero_explicit() was introduced as a security-critical fix.

**CISB Status**
yes

---

## Digest JSON

```json
{
  "function_contexts": [
    {
      "file_path": "crypto/sha256_generic.c",
      "primary_symbol": "static void sha256_transform(u32 *state, const u8 *input)",
      "changed_symbols": [
        "static void sha256_transform(u32 *state, const u8 *input)",
        "static int sha224_final(struct shash_desc *desc, u8 *hash)"
      ],
      "why_it_matters": "sha256_transform clears the intermediate W array after computation; sha224_final clears the D buffer. These contain sensitive hash state that must not be optimized away.",
      "code_summary": "In sha256_transform, replaced memset(W, 0, 64 * sizeof(u32)) with memzero_explicit(W, 64 * sizeof(u32)). In sha224_final, replaced memset(D, 0, SHA256_DIGEST_SIZE) with memzero_explicit(D, SHA256_DIGEST_SIZE)."
    },
    {
      "file_path": "crypto/tgr192.c",
      "primary_symbol": "static int tgr160_final(struct shash_desc *desc, u8 * out)",
      "changed_symbols": [
        "static int tgr160_final(struct shash_desc *desc, u8 * out)",
        "static int tgr128_final(struct shash_desc *desc, u8 * out)"
      ],
      "why_it_matters": "Both functions use a local D buffer to hold the full hash before truncation. Clearing D with memset may be optimized away, leaving sensitive hash data exposed.",
      "code_summary": "In tgr160_final and tgr128_final, replaced memset(D, 0, TGR192_DIGEST_SIZE) with memzero_explicit(D, TGR192_DIGEST_SIZE)."
    },
    {
      "file_path": "crypto/wp512.c",
      "primary_symbol": "static int wp384_final(struct shash_desc *desc, u8 *out)",
      "changed_symbols": [
        "static int wp384_final(struct shash_desc *desc, u8 *out)",
        "static int wp256_final(struct shash_desc *desc, u8 *out)"
      ],
      "why_it_matters": "Both functions use a local D buffer to hold the full Whirlpool hash before truncation. Clearing D with memset may be optimized away, leaving sensitive hash data exposed.",
      "code_summary": "In wp384_final and wp256_final, replaced memset(D, 0, WP512_DIGEST_SIZE) with memzero_explicit(D, WP512_DIGEST_SIZE). Also fixed minor formatting (removed space before parentheses in memcpy)."
    }
  ],
  "focused_contexts": [
    {
      "file_path": "crypto/sha256_generic.c",
      "reason": "Contains the memset replacement in sha256_transform, which clears the intermediate W array.",
      "slice_content": "  200 \tt2 = e0(e) + Maj(e,f,g);    h+=t1;    d=t1+t2;\n  201 \tt1 = c + e1(h) + Ch(h,a,b) + 0xa4506ceb + W[61];\n  202 \tt2 = e0(d) + Maj(d,e,f);    g+=t1;    c=t1+t2;\n  203 \tt1 = b + e1(g) + Ch(g,h,a) + 0xbef9a3f7 + W[62];\n  204 \tt2 = e0(c) + Maj(c,d,e);    f+=t1;    b=t1+t2;\n  205 \tt1 = a + e1(f) + Ch(f,g,h) + 0xc67178f2 + W[63];\n  206 \tt2 = e0(b) + Maj(b,c,d);    e+=t1;    a=t1+t2;\n  207 \n  208 \tstate[0] += a; state[1] += b; state[2] += c; state[3] += d;\n  209 \tstate[4] += e; state[5] += f; state[6] += g; state[7] += h;\n  210 \n  211 \t/* clear any sensitive info... */\n  212 \ta = b = c = d = e = f = g = h = t1 = t2 = 0;\n  213 \tmemset(W, 0, 64 * sizeof(u32));\n  214 }\n  215 \n  216 \n  217 static int sha224_init(struct shash_desc *desc)\n  218 {\n  219 \tstruct sha256_state *sctx = shash_desc_ctx(desc);\n  220 \tsctx->state[0] = SHA224_H0;\n  221 \tsctx->state[1] = SHA224_H1;\n  222 \tsctx->state[2] = SHA224_H2;\n  223 \tsctx->state[3] = SHA224_H3;\n  224 \tsctx->state[4] = SHA224_H4;\n  225 \tsctx->state[5] = SHA224_H5;\n  226 \tsctx->state[6] = SHA224_H6;\n  227 \tsctx->state[7] = SHA224_H7;\n  228 \tsctx->count = 0;\n  229 \n  230 \treturn 0;"
    },
    {
      "file_path": "crypto/sha256_generic.c",
      "reason": "Contains the memset replacement in sha224_final, which clears the D buffer.",
      "slice_content": "  299 \t/* Append length (before padding) */\n  300 \tcrypto_sha256_update(desc, (const u8 *)&bits, sizeof(bits));\n  301 \n  302 \t/* Store state in digest */\n  303 \tfor (i = 0; i < 8; i++)\n  304 \t\tdst[i] = cpu_to_be32(sctx->state[i]);\n  305 \n  306 \t/* Zeroize sensitive information. */\n  307 \tmemset(sctx, 0, sizeof(*sctx));\n  308 \n  309 \treturn 0;\n  310 }\n  311 \n  312 static int sha224_final(struct shash_desc *desc, u8 *hash)\n  313 {"
    },
    {
      "file_path": "crypto/tgr192.c",
      "reason": "Shows the context of tgr160_final where memset is replaced.",
      "slice_content": "  592 \t\tmemset(tctx->hash, 0, 56);    /* fill next block with zeroes */\n  593 \t}\n  594 \t/* append the 64 bit count */\n  595 \tle32p = (__le32 *)&tctx->hash[56];\n  596 \tle32p[0] = cpu_to_le32(lsb);\n  597 \tle32p[1] = cpu_to_le32(msb);\n  598 \n  599 \ttgr192_transform(tctx, tctx->hash);\n  600 \n  601 \tbe64p = (__be64 *)tctx->hash;\n  602 \tdst[0] = be64p[0] = cpu_to_be64(tctx->a);\n  603 \tdst[1] = be64p[1] = cpu_to_be64(tctx->b);\n  604 \tdst[2] = be64p[2] = cpu_to_be64(tctx->c);\n  605 \n  606 \treturn 0;\n  607 }\n  608 \n  609 static int tgr160_final(struct shash_desc *desc, u8 * out)\n  610 {"
    },
    {
      "file_path": "crypto/tgr192.c",
      "reason": "Shows the context of tgr128_final where memset is replaced.",
      "slice_content": "  609 static int tgr160_final(struct shash_desc *desc, u8 * out)\n  610 {\n  611 \tu8 D[64];\n  612 \n  613 \ttgr192_final(desc, D);\n  614 \tmemcpy(out, D, TGR160_DIGEST_SIZE);\n  615 \tmemset(D, 0, TGR192_DIGEST_SIZE);\n  616 \n  617 \treturn 0;\n  618 }"
    },
    {
      "file_path": "crypto/wp512.c",
      "reason": "Shows the context of wp384_final where memset is replaced.",
      "slice_content": " 1089    \tmemcpy(&buffer[WP512_BLOCK_SIZE - WP512_LENGTHBYTES],\n 1090 \t\t   bitLength, WP512_LENGTHBYTES);\n 1091    \twp512_process_buffer(wctx);\n 1092 \tfor (i = 0; i < WP512_DIGEST_SIZE/8; i++)\n 1093 \t\tdigest[i] = cpu_to_be64(wctx->hash[i]);\n 1094    \twctx->bufferBits   = bufferBits;\n 1095    \twctx->bufferPos    = bufferPos;\n 1096 \n 1097 \treturn 0;\n 1098 }\n 1099 \n 1100 static int wp384_final(struct shash_desc *desc, u8 *out)\n 1101 {"
    },
    {
      "file_path": "crypto/wp512.c",
      "reason": "Shows the context of wp256_final where memset is replaced.",
      "slice_content": " 1100 static int wp384_final(struct shash_desc *desc, u8 *out)\n 1101 {\n 1102 \tu8 D[64];\n 1103 \n 1104 \twp512_final(desc, D);\n 1105 \tmemcpy (out, D, WP384_DIGEST_SIZE);\n 1106 \tmemset (D, 0, WP512_DIGEST_SIZE);\n 1107 \n 1108 \treturn 0;\n 1109 }"
    }
  ]
}
```
