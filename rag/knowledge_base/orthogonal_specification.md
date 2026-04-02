# Orthogonal Specification

## Overview

Orthogonal Specification (OS) refers to security properties and requirements that must hold **regardless of the optimization level** applied by the compiler. These properties are "orthogonal" to the compiler's optimization decisions — they should be preserved no matter what transformations the compiler performs.

When compiler optimizations violate these orthogonal security requirements, the result is a Compiler-Introduced Security Bug (CISB).

## Core Principle

The fundamental principle of orthogonal specification is: **security-critical behaviors in source code must be preserved in the compiled binary, irrespective of optimization flags or compiler assumptions.**

This means that even if the compiler legally determines that certain operations are "unnecessary" from a functional perspective, those operations may be essential for security and must not be removed or altered.

## Categories of Orthogonal Security Properties

### 1. Sensitive Data Erasure

Programs must be able to reliably clear sensitive data (passwords, cryptographic keys, session tokens) from memory when it is no longer needed.

**Dead Store Elimination**: If a value written to memory is never subsequently read (from the compiler's perspective), the write may be removed:
   ```c
   // Developer intent: clear password from memory
   memset(password, 0, sizeof(password));
   free(password);
   // Compiler reasoning: password is freed immediately after, so the memset is "dead"
   // Optimization: removes the memset, leaving password in memory
   ```
**Violation example**: Dead Store Elimination removes `memset(key, 0, sizeof(key))` because the buffer is not read afterward. The sensitive key material remains in memory, vulnerable to cold boot attacks or memory disclosure vulnerabilities.

**Required property**: Memory clearing operations targeting sensitive data must persist through compilation regardless of whether the compiler considers them "useful."

### 2. Sensitive Data Exposure

This problem occurs when the sensitive data reaches out of the memory region its developer intends to enforce because of compiler optimizations. Such enforcement of the memory boundary of sensitive data is common such as the user space and kernel space in the OS kernel.

**Violation example**: The common cases are uninitialized structure padding and partial union initialization introduced by compilers, these memory objects may introduce information leak when passed out of kernel space.

**Required property**: In general, passing uninitialized memory within a single address space does not violate security; however, it becomes serious information leaks when data passes past the kernel/user boundary.

### 3. Constant-Time Operations

Cryptographic operations must execute in constant time to prevent timing side-channel attacks. Compiler optimizations must not introduce timing variations.

**Violation example**: The compiler replaces a constant-time comparison loop with an early-exit optimization, creating a timing side channel that leaks information about secret values.

**Required property**: Code explicitly written for constant-time execution must maintain its timing characteristics after compilation.

### 4. Memory Safety Barriers

Memory barriers, volatile accesses, and synchronization primitives used for security must be respected by the compiler.

**Violation example**: The compiler reorders memory operations across a security boundary, allowing a TOCTOU (Time-of-Check-Time-of-Use) attack.

**Required property**: Memory ordering constraints specified by the programmer for security purposes must be honored.

### 5. Micro-architectual Side Effects

Typically, a speculative execution side channel can be used to leak sensitive information. Code sequences with certain features are vulnerable to this side-channel attack. Due to the unawareness of such side effects, compilers may add such vulnerable features and bring side channel attack surface to created code.

```c
1  /* Before optimization*/ 
2  switch(x) {
3    case 0: return y;
4    case 1: return z;
5    ...  
6    default: return -1; 
7  }
8  /* After optimization*/  
9  if (x < 0 || x > 2) return -1;
10      goto case[x];
```
**Violation example**: Compilers can introduce speculative execution in bound-checks. The switch can be optimized to lines 9 and 10. Line 10 can now be speculatively executed regardless of the check at line 9, which can finally leak arbitrary information in memory through cache-based side channel attacks.

**Required property**: The root problem is that the optimization introduces microarchitectural side effects, and compilers are unaware of it.
## Relationship to CISB Detection

When analyzing a potential CISB, the Orthogonal Specification dimension helps answer:
- **Was there a security property that should have been preserved?** (e.g., "sensitive data must be cleared", "this check must not be removed")
- **Did the compiler optimization violate that property?**
- **Is the violation exploitable in the program's execution environment?**

The distinction between Implicit Specification and Orthogonal Specification is important: IS deals with the assumptions the compiler relies on for optimization, while OS deals with the security requirements that optimizations must not violate. A CISB typically involves an IS assumption enabling an optimization that violates an OS requirement.
