# 语法锚点策略：第二轮迭代验证

## 本轮修改

基于四个策略思路修改了 Querier prompt：

1. **Rule 1**（强制逐条映射）：要求 LLM 在 rationale 中将 equivalence_notes 逐条映射到 CodeQL AST 类型
2. **Rule 2**（getAChild*）：保留灵活 AST 匹配要求
3. **Rule 3**（builtin 名称）：保留
4. **Rule 4**（替代模板）：将"禁止硬编码"改为 WRONG/RIGHT 对照模板，教 LLM 用注释标记 Phase 2
5. **Rule 5**（API 边界）：新增表格，明确列出 root_cause_unit 禁用的 API（dominates / DataFlow / getLocation / getAnAttribute / getSize）
6. **新增 Spec Field Mapping 表**：明确 vulnerable_pattern → root_cause_unit（唯一来源），其他字段不用于语法建模

## 验证结果

对 failure_summary 前 10 个用例重新生成 QL，逐项对比：

| 用例 | 行数变化 | getAChild* | builtin | 硬编码 | 语义API泄漏 | 评价 |
|------|---------|-----------|---------|--------|-----------|------|
| b-6 | 77→42 ↓45% | 1 | 5 | 0 | 0 | **明显改善** |
| l-11 | 68→68 | 0 | 2 | 2 (__sparc__宏) | 2 (isDefined) | 未改善 |
| l-13 | 59→59 | 0 | 0 | 1 (getByteOffset>0) | 0 | 未改善 |
| l-15 | 81→81 | 0 | 6 | 0 | 0 | builtin改善 |
| l-16 | 92→92 | 12 | 0 | 0 | 2 (dominates+getLocation) | getAChild*大幅改善，语义API仍泄漏 |
| l-18 | 55→39 ↓29% | 0 | 3 | 0 | 0 | **明显改善** |
| l-19 | 104→104 | 2 | 4 | 0 | 0 | 未改善 |
| l-20 | 140→24 ↓83% | 0 | 0 | 0 | 1 (getAnAttribute) | **剧烈改善** |
| l-23 | 85→64 ↓25% | 0 | 1 | 1 | 1 | 部分改善 |
| l-25 | 32→32 | 0 | 0 | 1 (>20 cases) | 0 | 未改善 |

## 改善项

### 有效的改动

1. **Rule 5（API 边界表格）效果最显著**：l-20 从 140 行降到 24 行，l-18 从 55 降到 39，b-6 从 77 降到 42。把禁用 API 列成表格，LLM 在生成时有明确的"不要用这些"的检查清单。

2. **Rule 2（getAChild*）在部分用例上生效**：l-16 出现 12 处 `getAChild*()`，说明 LLM 开始有意识地用灵活匹配替代精确链。

3. **Rule 3（builtin）被普遍遵守**：新增的 `__builtin_` 变体和 `%name` 后缀匹配在多数 query 中出现。

### 改不动的顽固问题

1. **Rule 4（替代模板）对 l-25 无效**：prompt 里专门给了 switch 的 WRONG/RIGHT 示例（`> 20` vs `instanceof SwitchStmt`），LLM 仍然生成了 `getNumberOfCaseStmts() > 20`。这个例子直接打在 prompt 里都没拦住，说明 LLM 对"jump table = many cases"的先验太强。

2. **l-11 的架构宏检查顽固存在**：`__sparc__ && __arch64__` 的 `isDefined()` 检查同时违反 Rule 4（硬编码）和 Rule 5（isDefined 属于环境检查）。LLM 读 spec 看到"sparc64"，本能地翻译成了宏过滤。

3. **语义 API 泄漏仍有残留**：l-16 的 `dominates()` + `getLocation()` 比较，l-20 的 `getAnAttribute()` 过滤——Rule 5 降低了泄漏量（l-20 从 140→24），但没有完全消除。

## 策略有效性排序

| 策略 | 有效程度 | 说明 |
|------|---------|------|
| Rule 5: API 硬边界表格 | ★★★ 最有效 | l-20 -83%, l-18 -29%, b-6 -45% |
| Rule 3: builtin 名称 | ★★★ 普遍遵守 | 大多数 query 都加了 __builtin_ 变体 |
| Rule 2: getAChild* | ★★ 部分生效 | l-16 有 12 处，但其他 query 较少 |
| Rule 4: 替代模板 | ★ 基本无效 | l-25 的 switch 示例直接打在 prompt 里仍被忽略 |
| Rule 1: 逐条映射 | ? 无法验证 | rationale 字段内容未被直接检查 |

## 当前策略的根本矛盾

prompt 能做的是**约束 LLM 的输出行为**，但有两个边界是 prompt 无法越过的：

1. **LLM 对 spec 文本的"过度解读"**：spec 说"sparc64 architecture"，LLM 就会加 `__sparc__` 宏检查；spec 说"many cases"，LLM 就会加 `> 20`。这不是 LLM 不理解 prompt，而是 LLM 的推理链是 "spec 描述了什么 → 我应该用 CodeQL 表达它" —— 它很难做到 "spec 描述了但我要忽略它"。

2. **LLM 看不到生成结果是否命中**：没有反馈闭环，LLM 无从知道自己的 `> 20` 会把测试用例挡掉。prompt 只能事前约束，不能事后纠正。

## 后续思路

当前 prompt 修改方向的极限已基本触及——再加强约束的边际收益递减。后续可以考虑：

1. **两阶段生成**：先让 Querier 只生成 `root_cause_unit` 的纯 AST 部分（不生成 control_flow / environment），人工或自动验证语法锚点正确后，再调第二次生成完整 QL

2. **在 Querier 输入中加入反例**：不传 `.c` 文件，但可以把 failure_summary 中同类错误的模式抽象成"常见错误清单"附在 spec 后面，让 LLM 在生成时对照自查

3. **spec 层面做预处理**：在 Specifier 阶段就把 equivalence_notes 展开为具体 AST 类型映射，减少 Querier 的翻译负担
