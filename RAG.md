# RAG 模块文档 (Minimal PoC)

## 概述

本模块实现了 Scheme.md 中规划的 RAG（检索增强生成）路线图的第一阶段：**最小化 RAG**。

在 CISB（编译器引入的安全漏洞）检测任务中，LLM 往往面临两个核心挑战：一是对编译器内部优化逻辑与安全边界之间的复杂关系缺乏深刻理解；二是容易产生幻觉，将普通的编译器 Bug 或用户编程错误误判为 CISB。

本 PoC 通过构建一个轻量级的本地向量数据库，将经过人工整理的 CISB 核心定义、隐式规范、正交规范等领域知识注入 Reasoner 的上下文。这为模型提供了一个“标准参考手册”，使其在分析具体的 Bug 报告时能够有据可依，从而显著提升推理的准确性与可解释性。

## 目录结构

rag/ 目录下包含以下核心组件，共同构成了完整的检索流水线：

- **embedder.py**: 文本向量化模块。封装了 sentence-transformers 库，负责将自然语言文本转换为 384 维的稠密向量。
- **vector_store.py**: 向量存储模块。封装了 ChromaDB PersistentClient，负责向量数据的持久化存储、索引构建以及基于余弦相似度的向量检索。
- **retriever.py**: 核心检索逻辑类。该类是 RAG 模块的对外接口，集成了文档加载、语义切分、索引维护以及 Top-K 检索功能。它能够将检索结果自动格式化为适合 Prompt 注入的字符串。
- **test_rag.py**: 自动化测试脚本。包含了端到端的流程验证，通过预设的测试查询（如“什么是隐式规范？”）来评估检索系统的召回率和准确性。
- **knowledge_base/**: 原始知识库目录。存放了 4 个精心编写的 Markdown 文档，构成了本阶段的知识底座。
- **vector_db/**: 数据库持久化目录。存储了 ChromaDB 生成的二进制索引文件。该目录已被加入 .gitignore，以确保代码库的整洁。

## 依赖环境

本模块依赖于以下 Python 库，建议在项目的虚拟环境中运行：

- **chromadb**: 专为 AI 应用设计的轻量级向量数据库，支持本地持久化和高效检索。
- **sentence-transformers**: 提供了便捷的接口来调用 HuggingFace 上的预训练 Embedding 模型。
- **numpy**: 用于处理向量数据和执行基础的数值计算。

## 技术选型分析

在构建本 PoC 时，我们基于项目需求和研究环境做出了以下技术决策：

1. **向量数据库：ChromaDB vs FAISS**
   虽然 FAISS 在处理亿级数据时具有极高的检索效率，但其持久化管理相对原始。ChromaDB 提供了更完善的文档管理、元数据过滤以及开箱即用的持久化能力。对于目前的 PoC 阶段，ChromaDB 的易用性和功能完整性更符合快速迭代的需求。

2. **Embedding 模型：本地模型 vs OpenAI API**
   我们选用了本地运行的 `all-MiniLM-L6-v2` 模型。主要考量包括：
   - **数据隐私**：研究涉及的 Bug 报告和分析逻辑无需上传至云端。
   - **成本控制**：本地运行完全免费，适合大规模的实验测试。
   - **响应速度**：消除了网络延迟，检索过程几乎在毫秒级完成。
   - **性能匹配**：384 维向量足以捕捉技术文档中的语义特征，在我们的测试中表现优异。

3. **切分策略：基于标题的语义切分**
   传统的固定长度切分（Fixed-size Chunking）容易切断句子的完整性。我们采用了基于 Markdown 二级标题（##）的切分策略。这种方式能够确保每一个检索出的片段都是一个逻辑自洽的知识点，极大地提升了 LLM 对上下文的理解效率。

## 知识库内容详解

当前知识库由以下四个核心模块组成，涵盖了 CISB 研究的理论基石：

- **cisb_definition.md**: 明确了 CISB 的学术定义，强调了“编译器优化”这一核心变量，并将其与传统的软件漏洞进行了对比。
- **implicit_specification.md**: 深入探讨了编译器优化中的隐式规范。这些规范往往是开发者假设与编译器实现之间的“灰色地带”，是 CISB 产生的高发区。
- **orthogonal_specification.md**: 介绍了正交规范的概念。正交规范指的是那些无论编译器优化等级如何都必须保持的安全属性，例如敏感数据清除、安全检查保留、常量时间操作等。当编译器以"功能等价"为由移除这些安全相关操作时，就可能引入 CISB。
- **concept_distinctions.md**: 提供了清晰的概念辨析表，帮助模型区分 CISB、未定义行为（UB）、逻辑漏洞以及普通的编程错误。

## 核心类说明

### Retriever 类

`Retriever` 是本模块的核心入口，主要方法包括：

- `__init__(self, knowledge_base_path, db_path, model_name)`: 初始化检索器，指定知识库目录和向量数据库路径。参数均有默认值，可直接调用。
- `ingest_knowledge_base(self)`: 扫描 knowledge_base/ 目录下的 Markdown 文件，按 ## 标题切分后写入向量数据库，返回索引的文档片段数。
- `retrieve(self, query, top_k=3)`: 执行向量检索，返回包含 content、source、header、distance 的字典列表。
- `retrieve_as_context(self, query, top_k=3)`: 执行检索并将结果拼接成一段带有来源标识的文本，方便直接注入 Prompt。

## 使用方法

### 运行自动化测试

在项目根目录下执行以下命令：

```bash
python rag/test_rag.py
```

该脚本会输出索引构建状态以及针对典型问题的检索结果。

### 程序化调用示例

在你的 Python 脚本中，可以按照以下方式集成检索功能：

```python
import sys
sys.path.insert(0, "rag")
from retriever import Retriever

# 初始化检索器，首次使用需要先 ingest
retriever = Retriever()
retriever.ingest_knowledge_base()

# 获取相关的背景知识
query = "编译器优化如何导致安全检查失效？"
context = retriever.retrieve_as_context(query, top_k=2)

print("--- 检索到的上下文 ---")
print(context)
```

注意：由于项目不使用包结构（无 `__init__.py`），需要手动将 `rag/` 加入 `sys.path`，或从 `rag/` 目录内直接运行脚本。

## 与现有流水线的集成

RAG 模块被设计为 Reasoner 的“外部大脑”。在 `agents/wrapper.py` 或 `agents/reasoner.py` 中，可以根据 Bug 报告的摘要或描述动态检索知识。

集成逻辑示例：

```python
def generate_reasoning_prompt(self, bug_report):
    # 1. 检索相关领域知识
    knowledge = self.retriever.retrieve_as_context(bug_report['summary'], top_k=2)
    
    # 2. 构造增强后的 Prompt
    prompt = f"""
你是一个专门分析编译器安全漏洞的专家。
请参考以下领域知识来辅助你的判断：
{knowledge}

待分析的 Bug 报告如下：
ID: {bug_report['id']}
标题: {bug_report['title']}
描述: {bug_report['description']}

请根据以上信息，分步骤推理该问题是否属于 CISB。
"""
    return prompt
```

## 后续计划

根据 Scheme.md 的规划，RAG 模块将分阶段演进：

- **阶段 2 (基础版)**: 引入 C 语言标准文档（ISO/IEC 9899）和主流编译器（GCC/LLVM）的官方手册。这将为模型提供判定“编译器行为是否合规”的硬性准则。
- **阶段 3 (增强版)**: 扩展至硬件架构手册（如 Intel SDM）、微架构特性、密码学安全实现规范以及安全编码准则（如 CERT C）。目标是处理涉及硬件特性和复杂安全协议的 CISB。
- **阶段 4 (完整版)**: 实现基于 Agent 的自主 RAG。模型将不再是被动接收上下文，而是能够根据分析过程中的疑问，自主决定查询哪些知识库，并结合知识图谱进行深层次的关联推理。
