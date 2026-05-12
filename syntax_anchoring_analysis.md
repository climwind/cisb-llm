# 语法层面定位：当前策略问题和思路

## 验证样本

对 `failure_summary.md` 前 10 个失败用例，用修改后的 prompt 重新生成 QL 代码，逐个审查语法层面。

## 问题根因归类

从 10 个验证结果中，语法层定位失败可归结为 **4 个系统性问题**：

### 问题 1：等价形式枚举不完整

**典型代表**：l-13

spec 的 `equivalence_notes` 列出了 null-check 的 5 种等价语法形式。LLM 生成时覆盖了 `NEExpr`（`!= 0`）、`NotExpr+EQExpr`（`!(==0)`）、隐式 bool 三种，但漏了 `!&t->b` 这种"NotExpr 直接包裹 MemberAddressExpr"的形式。

不是 LLM 不理解它们的等价性，而是 LLM 做的是"语义理解式覆盖"而非"逐条对照式覆盖"。prompt 说"cover ALL forms"，LLM 只覆盖了它认为"主要的"那几条。

**本质**：缺少**强制逐条映射**的机制——LLM 没有被要求将 equivalence_notes 的每一条逐一翻译成 CodeQL AST 节点类型并自检。

### 问题 2：spec 文本 → AST 构造的翻译漂移

**典型代表**：l-18、l-15

l-18 的 `vulnerable_pattern` 描述的是"结构体整体赋值被编译器降为 memcpy"，但 LLM 生成的 `root_cause_unit` 建模的是 `IoWrapperFunction`（函数名匹配 `%_io`）+ `StandardMemCall`。LLM 读了 Description 字段里的"IO memory access wrappers"，把它当成了根因构造的一部分。

l-15 建模了函数**定义**层面的返回寄存器约定，但 spec 描述的是调用点的问题。

**本质**：spec 有多个字段（Description、Evidence、vulnerable_pattern、ql_constraints），LLM 在多个信息源之间漂移，没有锚定 `vulnerable_pattern` 作为根因构造的唯一来源。

### 问题 3：语义约束泄漏进语法层

**典型代表**：l-19（104 行）、l-20（140 行）

LLM 在 `root_cause_unit` 里塞入了：
- 控制流条件（`isConditionOnSyncVariable`、`writesToSharedVariable`）
- 环境假设（`isRetpolineDefined`、Section 的 attribute 过滤）
- 数据流关系（`localExprFlow`）

这些是后续语义约束的事，但混在语法锚点里导致：
- 语法层本身无法独立验证（关掉语义约束才能看到语法是否正确）
- 一旦某个语义约束写错，整个查询挂掉，无法定位是语法错还是语义错

**本质**：LLM 倾向于生成"完整"的东西。prompt 说"keep it simple ~40 lines"，但没有给出"什么叫太复杂"的具体判断标准，以及如何在当前阶段标记语义约束而非直接写入。

### 问题 4：数字阈值和名称白名单的惯性

**典型代表**：l-25、l-11

l-25 的 `> 20 cases`——spec 里写的可能是"many cases"或"large switch"，LLM 自动翻译成了数字阈值。这是 SA4 规则被直接违反的最典型案例。

l-11 的 `__sparc__ && __arch64__`——spec 提到 sparc64 架构，LLM 把它写成了硬编码的预判宏过滤。

**本质**：prompt 说"不要硬编码"，但 LLM 不知道替代做法是什么。遇到 spec 里的描述性语言，LLM 的本能是把它翻译成 CodeQL 过滤条件。prompt 需要给出具体的**替代模板**——不是只说"禁止"，而是教 LLM "用注释标记待 Phase 2 处理"。

---

## 策略思路

四个问题的共同根因：**spec 文本到 CodeQL AST 之间缺少一个结构化的中间表示**。LLM 直接从自然语言 spec 跳到 CodeQL 代码，中间没有约束翻译步骤。

修改 prompt 的方向不是加更多"不要怎样"的禁令（SA4 已经说了不要硬编码，LLM 还是加了），而是：

### 思路 1：强制逐条映射（针对问题 1）

要求 LLM 在生成代码前，先把 `equivalence_notes` 的每一条翻译成具体的 CodeQL AST 节点类型，写在 rationale 字段里，自检是否有遗漏。

具体做法：在 prompt 里要求 LLM 先生成一个映射表——

```
equivalence_note: "x == NULL and !x are equivalent" 
→ CodeQL: EQExpr(VariableAccess, NullLiteral) OR NotExpr(VariableAccess)
→ Self-check: covered both? YES
```

然后再写代码。如果映射表里缺少某条，代码里就一定缺。

### 思路 2：锚定单一信息源（针对问题 2）

明确告诉 LLM 各字段的用途边界：

- `vulnerable_pattern` → `root_cause_unit` 的**唯一**来源
- `ql_constraints` → `control_flow_unit` 和 `environment_unit` 的来源
- `equivalence_notes` → 语法等价形式的**必覆盖清单**
- Description/Evidence/Requirement/Mitigation → 背景信息，**不作为 CodeQL 建模的直接依据**

### 思路 3：分离语法-语义的硬边界（针对问题 3）

在 prompt 里给出清晰的判断标准——"以下 CodeQL API 一旦出现在 root_cause_unit 里，就说明语义约束泄漏了"：

- `dominates()` → 属于 control_flow_unit
- `DataFlow::` → 属于 Phase 2
- `.getLocation()` 的行号比较 → 属于 control_flow_unit
- `.getAnAttribute()` 过滤 → 属于 environment_unit
- `.getSize()` / 数字比较 → 属于 environment_unit

同时在输出格式里要求 LLM 标注 root_cause_unit 预计行数，超过 40 行则自检是否混入了语义约束。

### 思路 4：给替代模板而非禁令（针对问题 4）

不只是说"不要硬编码阈值和名称白名单"，而是给模板：

```
// WRONG: hardcoded threshold
this.getNumberOfCaseStmts() > 20

// RIGHT: treat it as a comment for Phase 2
// Phase 2 note: restrict to switches with enough cases to trigger jump tables
this instanceof SwitchStmt
```

```
// WRONG: hardcoded architecture check
exists(Macro m | m.getName() = "__sparc__" and m.isDefined())

// RIGHT: defer to Phase 2
// Phase 2 note: restrict to architectures where padding behavior differs
```

让 LLM 知道"不硬编码"的具体替代做法是什么，而不是只给否定指令。
