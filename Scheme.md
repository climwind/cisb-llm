# RAG 来源文档收集

初步考虑，我们需要关注以下层面的信息：

- C11 语言标准
- 编译器手册
- 硬件和系统 ABI 规范
- 安全与微架构规范
- IS 和 OS 相关概念区分和 CISB 限制，主要是 study

进一步，我们按照 IS 和 OS 的区分，可以将这些分为两大类：

- IS-target
  - C 语言标准
  - 编译器（GCC、LLVM）手册
  - 行业安全编码标准
  - 硬件与 ABI 规范
- OS-target
  - 安全编码规范
  - 密码学工程和规范
  - 硬件安全和微架构漏洞指南

# RAG 扩展

![](C:/Users/admin/Downloads/RAG.drawio.png)



按照以下四步：

1. 最小化 RAG：只包含 CISB 定义和规范：IS/OS 即 study 的 2.1 节，3-5 章，以及相关概念如编程错误的区分。
2. 基础版 RAG：加入 C 语言标准、编译器手册相关章节内容。
3. 增强版 RAG：从加入更多规范性内容如硬件、微架构、密码学以及行业内的安全编码规范。
4. 完整版 RAG：让 LLM 学会自己调用向量数据库查询，做成一个 Agent。将已有的知识结构化成知识图谱。

# RAG 进展

目前先进行最小化的 RAG 相关 PoC，需要收集以下信息：

- CISB 的定义与限制（2.1 节）
- CISB 规范 Implicit Specificaiton/Orthogonal Specification：3-5 章
- 相关概念区分：Undefined Behavior、Default Behavior、Environment Assumption。

# 原始 Prompt

你是一个 LLM 技术专家。现在我想要将编译器引入型漏洞（CISB）的相关知识和规范做成向量数据库，然后作为 RAG 方便 LLM 在辨析相关概念和筛选 CISB 时查询数据库获取领域知识，以降低幻觉。

目前我写了一份简要的方案，里面包含了我对 RAG 方案的考虑和大致内容，即 @Scheme.md ，你只需要完成其中的最小化的 RAG 方案的 PoC。方案的大致内容见 @Scheme.md 的 RAG 进展一节。注意，方案中提到的章节信息指 @CISB-study.pdf 中的内容。

请你拟定一份计划，实现最小化的 RAG 方案，你应该按照 RAG 建立的经典流程分步骤进行，每个阶段完成后进行检查。