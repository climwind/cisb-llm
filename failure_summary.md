# CISB Failure Summary

本文件只总结“结果条数为 0”的类型。每种类型记录：

- 目标查询模式
- 当前 QL 实际能查询到的模式
- 两者之间的差距
- 本次未命中的直接原因

## `queries/b-6__modify_const_var`

- 目标查询模式：通过去掉 `const` 的指针转换写入 `const` 变量，例如样例中的 `*((char**)(unsigned long int)((&kern_buff_p))) = ...`。
- QL 实际可匹配模式：更接近“直接把 `&const_var` 转成非 `const` 指针后写入”的单段 cast-dropping-const 形态。
- 差距：样例是“指针地址先转整数，再转回指针，再解引用写入”的跨整数桥接 cast 链，不是单段去 `const`。
- 未命中原因：`rootCauseUnit` 依赖特定转换链形状，无法稳健覆盖“指针 -> 整数 -> 指针”的写法。

## `queries/l-11__padding_copied_to_user_space`

- 目标查询模式：结构体按字段逐个赋值，未做整体初始化，随后整体拷贝到用户空间，造成 padding 泄漏。
- QL 实际可匹配模式：直接字段赋值到同一个对象表达式，并调用白名单函数 `copy_to_user`、`memcpy` 或 `uinput_send_event` 进行拷贝。
- 差距：样例使用的是 `opaque_copy(user, &sa, sizeof(sa))`，而且字段写入包含 `sa.addr.addr_type` 这类嵌套路径；查询既不认该 API，也不能把嵌套成员归并到顶层对象。
- 未命中原因：拷贝函数名不在白名单，且字段赋值与 `&sa` 无法统一到同一个 `structInst`。

## `queries/l-13__ub_pointer_offset_overflow`

- 目标查询模式：`&ptr->field` 被当成空值检查条件，且 `field` 偏移大于 0，触发基于 UB 的优化。
- QL 实际可匹配模式：只匹配 `&ptr->field != NULL` 或 `!(&ptr->field == NULL)`，且表达式必须是循环控制条件。
- 差距：样例是普通 `if (!&t->b)`，既不是 loop condition，也不是这两种比较写法。
- 未命中原因：`query.ql` 只选 `isInLoopCondition(vcheck)`，同时 `VulnerableMemberCheck` 不覆盖 `NotExpr(AddressOfExpr(FieldAccess))`。

## `queries/l-15__db_transfer_mem_load_to_reg_load`

- 目标查询模式：调用点依赖 `memset`/ABI 返回寄存器约定，导致后续寄存器值污染。
- QL 实际可匹配模式：查“第一个参数应该流到返回值，但函数没有直接返回第一个参数”的函数定义。
- 差距：样例是 `void` 函数中的 `memset` 调用点问题，不是“函数错误返回第一个参数”的定义点问题。
- 未命中原因：样例没有 `return` 表达式，而查询又把根因建模在函数返回约定上，语义对象不一致。

## `queries/l-16__ub_nonull_ptr_assumption`

- 目标查询模式：先通过 asm/prefetch 等对指针做访问，编译器据此假设非空，再删除后续空指针判断。
- QL 实际可匹配模式：某个 asm 语句支配某个 null-like 判断，判断形式只接受 `== NULL`、`!= NULL`、`< 0`、`> 0` 或 `!ptr`。
- 差距：样例是 `prefetch(x); if (x) ...`，属于正向真值检查，不是 null-like 判断；同时入口查询没有把 `rootCauseUnit` 接进来。
- 未命中原因：`isNullCheck` 不覆盖 `if (x)`，且 `query.ql` 没有把 asm 中真正被访问的变量与 `if` 条件变量闭合起来。

## `queries/l-18__env_varient_memcpy_unaligned_ldx`

- 目标查询模式：结构体整体赋值/初始化被后端降成 `memset`/`memcpy`，即便禁用 builtin 也仍发生。
- QL 实际可匹配模式：IO wrapper 函数中显式调用 `memset`、`memcpy`、`__builtin_memset` 或 `__builtin_memcpy`。
- 差距：样例是普通函数中的聚合赋值 `y = x;`，没有显式内存库调用，也不是 IO wrapper。
- 未命中原因：环境约束和语法形态都偏向“IO wrapper + 直接调用标准内存函数”，与样例不符。

## `queries/l-19__conditional_load_non_conditional_load`

- 目标查询模式：条件相关访问在优化后变成非条件访问，样例体现的是 early return 形成的控制依赖。
- QL 实际可匹配模式：`if` 的 then 分支内部出现对全局/静态变量的共享写，且条件依赖某同步变量。
- 差距：样例中的共享写出现在 `if (g_1) return l;` 之后，不在 then 分支内部；查询用词法包含关系代替了真实控制依赖。
- 未命中原因：`isGuardedByCondition` 只认 then 子树内部的 store，无法识别“条件失败后执行后续 store”的模式。

## `queries/l-20__db_invention_of_unaligned_mem_access`

- 目标查询模式：同一 linker section 中对象对齐不一致，随后按固定步长遍历 section，把 padding 当成合法元素读取。
- QL 实际可匹配模式：缺少显式 `aligned` 属性、放入 section 的单个 struct/union 变量。
- 差距：真实问题需要比较多个 section 对象及其遍历方式；查询只看单个“无 aligned”的变量。
- 未命中原因：样例里的关键对象明确带有 `aligned(4)` / `aligned(32)`，被根因谓词直接排除。

## `queries/l-23__env_transfer_memcpy_to_unaligned_ldx`

- 目标查询模式：`memcpy` 写入结构体内部非对齐成员后，后端生成需要自然对齐的加载指令。
- QL 实际可匹配模式：无 `aligned` 属性且大小为 8 的 struct 类型，外加一个抽象的 8 字节 access/call。
- 差距：真实问题依赖 `memcpy(&p->num2, ..., 8)` 这种对子字段地址的复制；查询没有建模 `memcpy`、成员偏移或后端指令选择。
- 未命中原因：样例类型带有 `aligned(4)`，先被 `RootCauseUnit` 排除；同时查询本身也偏向“整个 struct 的访问”，不是成员地址复制。

## `queries/l-25__switch_jump_table`

- 目标查询模式：在需要 retpoline 的环境里，编译器仍把 `switch` 生成为 jump table，从而绕过缓解。
- QL 实际可匹配模式：`case` 数量大于 20 的 `switch`，其余环境约束基本为空。
- 差距：真实问题依赖目标架构、编译选项和代码生成；查询把“会生成 jump table”近似成了“case 数 > 20”。
- 未命中原因：样例只有 5 个 `case`，不满足 `count(s.getASwitchCase()) > 20`。

## `queries/l-29__part_of_union_not_init`

- 目标查询模式：先整体清零 union，再写一个成员，最后通过另一成员路径读取相同底层存储。
- QL 实际可匹配模式：qualifier 类型是 union 的 `FieldAccess`，并要求两个字段访问有同一个 qualifier AST 节点、但目标字段不同。
- 差距：真实问题需要建模 `memset` 和“同一 union 对象”的别名关系；查询只在 AST 上比较两个字段访问节点。
- 未命中原因：`accessesDifferentMemberPath` 把“同一个对象”建模得过严，无法稳定识别样例中的跨成员初始化关系。

## `queries/l-30__ub_concurrency_access_to_global_between_2_func_call_which_contains_access_to_same_global`

- 目标查询模式：两个函数调用之间同一全局变量发生隐式并发变化，优化器错误消除第二次读取/调用。
- QL 实际可匹配模式：同一函数内模板相同的两个非 `volatile` 内联汇编语句。
- 差距：目标样例是全局变量并发访问，查询却完全建模成了“重复的非易失内联汇编”。
- 未命中原因：样例没有内联汇编，`NonVolatileAsm` 候选为空。

## `queries/l-35__env_implicit_read_between_2_stores`

- 目标查询模式：前置写入在调用缺少 `"memory"` clobber 的内联汇编前被优化器错误消除；关键是汇编通过指针隐式读内存。
- QL 实际可匹配模式：缺少 `memory` 字符串且含指针类型子表达式的 `AsmStmt`，再要求某个赋值/函数调用语句支配该 asm。
- 差距：真实问题需要把“前一条写入”和“汇编实际读到的内存”关联起来，而且样例是跨函数的调用者写入与被调函数 asm 的关系；查询只有粗粒度的语句级支配关系。
- 未命中原因：样例中的写入在 `main`，危险 asm 在被调函数内部，当前控制流约束无法跨过程建立关系。

## `queries/l-38__reorder_cpu_check`

- 目标查询模式：受运行时条件保护的内联汇编因为缺少 `memory` clobber，被编译器跨条件重排。
- QL 实际可匹配模式：asm 语句本身必须直接位于某个 `if/else` 的语法子树中，且 asm 字符串还要命中 `mrc|mcr|cp15|hardware|capability|smp|barrier`。
- 差距：样例是“`if` 条件调用一个内部含危险 asm 的函数”，不是“asm 直接嵌套在 if 里”；同时样例 asm 是 x86 `pushfq/popfq/xorq`，不含这些关键字。
- 未命中原因：条件保护和硬件相关性都被建模得过于窄，两个约束都把样例挡掉了。

## `queries/l-43__env_built_in_replace`

- 目标查询模式：循环逐元素写入被编译器替换成 `memset` 等 bulk memory operation，在设备/I/O 内存上产生问题。
- QL 实际可匹配模式：循环体内顺序写入，且目标类型必须是 `volatile` 或名称匹配 `_iomem`、`ioport`、`mmio`。
- 差距：样例展示的是普通数组也会被替换成 `memset`，而查询把环境强行收缩到了设备/I/O 内存。
- 未命中原因：样例目标数组是普通 `unsigned int a[100]`，不满足 `environmentUnit`。

## `queries/l-44__db_byte_wide_word_wide`

- 目标查询模式：编译器基于更强对齐假设，把逐字节的未对齐访问优化成字宽访问。
- QL 实际可匹配模式：`extern` 的整型变量、隐式对齐大于 1 字节、且没有 `aligned/packed` 属性，然后再匹配对该变量的访问。
- 差距：样例真正的对齐假设来自 `__builtin_assume_aligned`，不是外部变量声明。
- 未命中原因：样例没有任何符合根因条件的 `extern` 变量，建模对象完全错位。

## `queries/l-48__db_reorder_bpf`

- 目标查询模式：`switch` 的 fall-through 让不同宽度的内存访问串在一起，优化器再复制或重排地址计算后产生越界或宽度错配。
- QL 实际可匹配模式：fall-through case + 内存访问 + 指针 `AddExpr/SubExpr` 地址计算，且没有 barrier。
- 差距：样例的核心是“不同读取宽度的 case 通过 fall-through 混在一起”，并没有显式指针算术；查询却把重点放在地址计算与 barrier 上。
- 未命中原因：样例体现的是类型宽度选择错误，不是指针算术重排，因此 `isAddressCalculation` 相关路径无法成立。

## `queries/l-4__data_race`

- 目标查询模式：把共享字段缓存到局部变量，再在缺少 `READ_ONCE/ACCESS_ONCE/volatile` 的情况下反复判空或解引用。
- QL 实际可匹配模式：右值是 `FieldAccess` 的赋值表达式，再要求从该右值流到赋值左值节点、再从该左值节点流到后续使用。
- 差距：真实语义是“变量被赋值后在后续语句里被使用”，而查询把 `cachedVar` 固定成赋值左侧那一次 AST 出现，缺少真正的 def-use 建模。
- 未命中原因：`localExprFlow` 无法自然表达“赋值后变量在后续语句中被使用”的关系，因此样例虽然贴近描述，仍未命中。

## `queries/l-5__ub_data_race`

- 目标查询模式：先读取共享数据，再读取同步标志；缺少顺序约束时编译器可能重排读取顺序。
- QL 实际可匹配模式：从某个指针/引用基对象流向一个“`bool` 类型的同步标志读取”和一个“非 `bool` 的数据读取”，并比较它们的行号先后。
- 差距：样例同步标志是从 `uint32_t d0` 提取出来的 ready bit，不是 `bool` AST 节点；数据读取还通过 `memcpy` 做 bulk copy。
- 未命中原因：`hasSyncFlagRead` 把同步标志硬编码成了 `bool` 读取，且查询没有专门建模 `memcpy` 复制出的 payload 读取。

## `queries/l-8__ub_elimi_shift`

- 目标查询模式：移位量未检查，后续对移位结果的健全性检查被编译器基于 UB 优化掉。
- QL 实际可匹配模式：`if` 条件语法树中直接包含 `LShiftExpr/RShiftExpr`，并对该移位右操作数应用“未检查”判断。
- 差距：样例是先 `g = 1 << size;`，再在后续 `if` 中检查 `g`；查询只覆盖“移位表达式直接内联在 if 条件里”的写法。
- 未命中原因：查询没有做 def-use 追踪，不能把 `if (g == ...)` 追溯回前面的移位表达式。
