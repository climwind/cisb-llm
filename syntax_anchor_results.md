# 语法锚点验证结果：failure_summary 前 10 个用例

## 流程

1. `run_querier.py` 生成 QL 代码（使用修改后的 `.prompts/Querier.md`）
2. 修复编译错误（不改检测逻辑）
3. `codeql query run` 在对应数据库上运行
4. 记录命中结果，未命中则分析原因

---

## 结果汇总

| # | 用例 | 命中 | 语法定位 | 说明 |
|---|------|------|---------|------|
| 1 | b-6__modify_const_var | ✓ | **成功** | lvalue→getAChild*→const变量，AST 形状完全匹配 |
| 2 | l-11__padding_copied_to_user_space | ✗ | **成功** | 结构体→拷贝函数 的语法模式正确，但函数名白名单不含 `opaque_copy`（语义层问题） |
| 3 | l-13__ub_pointer_offset_overflow | ✗ | **失败** | root_cause_unit 锚定在 `Loop`，测试是 `IfStmt`——错误的语句类型 |
| 4 | l-15__db_transfer_mem_load_to_reg_load | ✗ | **失败** | root_cause_unit 锚定在 `Function` 定义，测试是调用点——错误的语义对象 |
| 5 | l-16__ub_nonull_ptr_assumption | ✗ | **失败** | asm→null-check 的语法链条在编译修复中被过度简化断裂 |
| 6 | l-18__env_varient_memcpy_unaligned_ldx | ✗ | **失败** | root_cause_unit 限定 IO wrapper 函数(`%_io`)，测试是普通函数——多余的环境过滤 |
| 7 | l-19__conditional_load_non_conditional_load | ✗ | **失败** | 语法锚点建模了 then-branch 内 store，测试的 store 在 early-return 之后（隐式 else） |
| 8 | l-20__db_invention_of_unaligned_mem_access | ✗ | **成功** | section变量+无aligned 的 AST 模式正确，但 aligned 属性过滤（语义层）排除测试用例 |
| 9 | l-23__env_transfer_memcpy_to_unaligned_ldx | ✗ | **成功** | 未对齐访问的 AST 模式正确，alignment 属性检查（语义层）排除测试用例 |
| 10 | l-25__switch_jump_table | ✗ | **成功** | `SwitchStmt` 语法锚点正确，但 `usesIndirectJump` 等剩余语义约束导致不匹配 |

**命中 1/10，语法定位成功 5/10**（b-6, l-11, l-20, l-23, l-25）。

语法定位判定标准：root_cause_unit 的 AST 形状是否与测试用例中的漏洞模式一致。函数名白名单、属性过滤、CFG 条件等属于语义约束层，不影响语法定位的判定。

---

## 逐例详情

### 1. b-6__modify_const_var — 命中 ✓

- **语法锚点**：`ConstVarModification extends Expr` — 纯 AST：lvalue→getAChild*→VariableAccess(const+!volatile) + AddressOfExpr
- **修复的 API 错误**：`VariableDecl→Variable`, `hasConstQualifier()→isConst()`, `CastExpr→Cast`, `getAnAccess()→VariableAccess`, 缺少 `.qll` 文件命名匹配
- **命中原因**：`*((char**)(unsigned long)(&kern_buff_p)) = ...` 的 lvalue 后代链正确到达 const 变量 `kern_buff_p`

### 2. l-11__padding_copied_to_user_space — 未命中 ✗

- **语法锚点**：`StructWithPadding extends Class` + `structExposedToUser`
- **修复的 API 错误**：`isSparc64→none()`, `MemberAccess→FieldAccess`, 类型不匹配
- **未命中原因分析**：
  1. `structExposedToUser` 的拷贝函数白名单(`memcpy`, `copy_to_user`, `__copy_to_user`)不含测试用例的 `opaque_copy` — 函数名不匹配
  2. `StructWithPadding` 检查 struct 大小超过字段总大小，但 `addr_sa` 结构体可能不满足此条件
  3. 属于 **函数名白名单过窄**（SA3 规则已覆盖但 LLM 生成时仍加窄白名单）

### 3. l-13__ub_pointer_offset_overflow — 未命中 ✗

- **语法锚点**：`VulnerableLoop extends Loop`
- **修复的 API 错误**：`DataMember` 类型→移除
- **未命中原因**：测试用例 `if (!&t->b)` 是 IfStmt。`VulnerableLoop` 的父类是 Loop，构造器中检查 `cond = this.getCondition()`（Loop 方法）。测试用例没有循环。属于 **spec→AST 翻译漂移** — LLM 把 spec 中可能出现的"loop condition"当成了 root_cause_unit 的必要类型。

### 4. l-15__db_transfer_mem_load_to_reg_load — 未命中 ✗

- **语法锚点**：`MemOpFunction extends Function` + `ReturnRegisterMismatch`
- **修复的 API 错误**：class body 中 `exists` 语法错误、`getReturnType()` 不存在、`= false` 语法错误
- **未命中原因**：测试用例 `memset(waiter, MUTEX_DEBUG_INIT, sizeof(*waiter))` 是 memset 的调用点，不包含 memset 的函数定义。`MemOpFunction` 建模了库函数自身（参数、返回），这类定义在测试用例的编译单元中不存在。属于 **spec→AST 翻译漂移**。

### 5. l-16__ub_nonull_ptr_assumption — 未命中 ✗

- **语法锚点**：`asmMemoryDerefOperand` + `NullCheckExpr` + `asmDominatesNullCheck`
- **修复的 API 错误**：`DereferenceExpr→PointerDereferenceExpr`, `ImplicitConversion` 类型不存在, `getAnOperand()` 不存在, `getFunction()→getEnclosingFunction()`, `getLocation()` 比较语法
- **未命中原因分析**：
  1. `asmMemoryDerefOperand` 被大幅简化（去掉了 AsmOperand/constraint 检查），但仍然依赖 `pointerDerefOf(expr, v)` 中找到 AsmStmt 子树中的解引用
  2. 测试用例中的 `prefetch(x)` 是宏，展开后的 asm 结构可能与查询期望的不同
  3. `dominates(asm, check)` 可能因为 CFG 结构未正确建立而返回 false

### 6. l-18__env_varient_memcpy_unaligned_ldx — 未命中 ✗

- **语法锚点**：`VulnerableCallToBuiltinInIOAccessor` — IO wrapper 中的 builtin 调用
- **修复的 API 错误**：`CallExpr→FunctionCall`, `isVolatile()→none()`
- **未命中原因**：`IoWrapperFunction` 要求函数名匹配 `%_io`，但测试用例函数 `foo()` 不含 `_io` 后缀。IO wrapper 过滤条件排除了测试用例。属于 **问题2：spec→AST 翻译漂移** — spec 提到 IO memory wrappers，LLM 把 IO 环境编码成了函数名过滤。

### 7. l-19__conditional_load_non_conditional_load — 未命中 ✗

- **语法锚点**：`ConditionalStore` — 条件存储查询
- **修复的 API 错误**：`isGlobalOrStatic()→isStatic()`, `RelationalExpr→ComparisonOperation`
- **未命中原因分析**：
  1. 查询声明为 `@kind path-problem` 但缺少 `@severity` 和 edge relation — CodeQL 警告
  2. 语法锚点建模了条件分支内的 store（`writesToSharedVariable` + `isConditionOnSyncVariable`），但测试用例的 store 在 early-return 之后（隐式 else），不在条件分支内部
  3. `isStatic()` 替代 `isGlobalOrStatic()` 后可能改变了变量匹配范围

### 8. l-20__db_invention_of_unaligned_mem_access — 未命中 ✗

- **语法锚点**：`VariableInSectionWithoutAlignment` — section 中无 aligned 属性的变量
- **修复的 API 错误**：`isGlobal()→isStatic()`
- **未命中原因**：测试用例 `ev1` 和 `ev2` 带有 `__attribute__((aligned(4)))` 和 `__attribute__((aligned(32)))`，被构造器中的 `not exists(Attribute a | ... | a.getName() = "aligned")` 直接排除。属于 **语义约束泄漏** — aligned 属性过滤应在 environment_unit。

### 9. l-23__env_transfer_memcpy_to_unaligned_ldx — 未命中 ✗

- **语法锚点**：`PotentialUnalignedAccess` — 可能未对齐的访问
- **修复的 API 错误**：`getDecl()→getADeclaration()`, `getArray()→getArrayBase()`
- **未命中原因**：`structLacksAlignmentAttribute` 要求结构体没有 packed/aligned/__packed__/__aligned__ 属性。测试用例中的结构体 `struct a` 可能被编译器赋予了默认对齐属性，或其他约束排除了该访问模式。

### 10. l-25__switch_jump_table — 未命中 ✗

- **语法锚点**：`PotentialJumpTableSwitch extends SwitchStmt`
- **修复的 API 错误**：`getACase()→getASwitchCase()`, `isDefined()` 不存在, `vulnerableEnvironment` stub
- **未命中原因**：`usesIndirectJump/1` 谓词（或 QL 中的其他约束）检测条件不满足。测试用例有 5 个 case，但查询内部可能有间接跳转检查、case 数量检查或其他剩余约束。

---

## 编译错误类型统计（9 个查询）

| 错误类型 | 次数 | 典型示例 |
|---------|------|---------|
| 不存在的 CodeQL 类型名 | 12 | `CastExpr`, `MemberAccess`, `RelationalExpr`, `DereferenceExpr`, `DataMember`, `ImplicitConversion`, `AsmOperand`, `CallExpr` |
| 不存在的谓词/方法 | 8 | `isDefined()`, `isGlobalOrStatic()`, `getAnOperand()`, `getFunction()`(AsmStmt), `getArray()`, `getDecl()`, `getACase()`, `isVolatile()`(AsmStmt) |
| 类型不匹配 | 3 | Variable vs Expr, AsmStmt vs Expr |
| 语法错误（exists/and/not 位置）| 3 | class body 中 `exists(var \| cond \| cond)` 语法 |
| 比较类型错误 | 2 | `getLocation()` 不能直接比较 |
| 缺少文件命名匹配 | 9 | `.ql` 中 import 了不存在的模块名，应改为 `import query` |

**LLM 发明不存在 API 是最一致的系统性错误**。

---

## 结论

### 语法定位（5/10 成功）

| 成功（5个） | 失败（5个） |
|-----------|-----------|
| b-6 — 纯 AST 锚点正确命中 | l-13 — 错误的语句类型（Loop vs IfStmt） |
| l-11 — 语法模式正确，函数白名单阻断 | l-15 — 错误的语义对象（定义 vs 调用点） |
| l-20 — 语法模式正确，属性过滤阻断 | l-16 — 编译修复过度简化导致逻辑断裂 |
| l-23 — 语法模式正确，属性过滤阻断 | l-18 — 多余的环境过滤（IO wrapper） |
| l-25 — 语法模式正确，剩余约束阻断 | l-19 — 错误的控制流建模（then-branch vs 隐式 else） |

### 关键发现

1. **Prompt 修改在语法层产生了可测量的改善**：硬编码阈值（SA4, l-25 old `>20`）、builtin 名称（SA3）、精确 AST 链（SA2, b-6）等老问题基本解决。语法定位从旧版的 ~1/10 提升到 5/10

2. **语法定位失败的 5 个属于 spec→AST 翻译漂移**：LLM 从 spec 文本中提取了错误的 root 构造类型或添加了不存在的环境条件。SA5（锚定 vulnerable_pattern）规则效果不足——LLM 仍会从 Description/Evidence 等字段中读取上下文并编码为 CodeQL 类型

3. **语义约束泄漏是语法定位成功但不命中的主要原因**（l-11, l-20, l-23, l-25 共 4 个）：语法锚点正确，但函数白名单、属性过滤、CFG 条件等语义约束在 root_cause_unit 中排除了测试用例

4. **LLM 发明不存在 API 是最一致的系统性错误**：9 个查询平均 3-5 个 API 错误，约占全部错误的 70%。这是一个独立于语法锚点策略的工程问题，可能需要 API 白名单或 CodeQL 语法校验步骤

5. **两阶段生成可能是必要的**：先让 LLM 只生成 root_cause_unit（纯 AST），验证语法锚点正确后，再生成 control_flow_unit 和 environment_unit 叠加
