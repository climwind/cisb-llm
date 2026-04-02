# Minimal RAG PoC for CISB Knowledge Base

## 1. TASK

Implement a minimal RAG (Retrieval-Augmented Generation) proof-of-concept for CISB (Compiler-Introduced Security Bugs) domain knowledge. This is Phase 1 of a 4-phase RAG implementation plan.

**Scope**: Build a functional RAG system that can:
- Store and index CISB domain knowledge documents
- Retrieve relevant context when given a query about CISB concepts
- Provide the retrieved context to support LLM reasoning

**Knowledge Base Content** (extract from project context):
- CISB Definition and Constraints (Section 2.1)
- CISB Specifications: Implicit Specification (Chapter 3) and Orthogonal Specification (Chapters 4-5)
- Concept Distinctions: Undefined Behavior (UB), Default Behavior, Environment Assumption, Programming Error

## 2. EXPECTED OUTCOME

**Files to Create**:
- [ ] `rag/` directory with the following structure:
  - `rag/__init__.py` - Package initialization
  - `rag/vector_store.py` - Vector database wrapper (ChromaDB or FAISS)
  - `rag/embedder.py` - Text embedding interface (OpenAI or local embeddings)
  - `rag/retriever.py` - RAG retrieval logic
  - `rag/knowledge_base/` - Directory containing knowledge documents
    - `cisb_definition.md` - CISB definition and constraints
    - `implicit_specification.md` - Chapter 3: Implicit Specification
    - `orthogonal_specification.md` - Chapters 4-5: Orthogonal Specification
    - `concept_distinctions.md` - UB, Default Behavior, Environment Assumption definitions
  - `rag/test_rag.py` - Test script demonstrating RAG functionality

**Functionality**:
- [ ] Can ingest markdown documents and create embeddings
- [ ] Can retrieve top-k relevant documents given a query
- [ ] Test script demonstrates: query → retrieval → context augmentation

**Verification**:
- [ ] `python rag/test_rag.py` runs without errors
- [ ] Query "What is CISB?" returns relevant definition
- [ ] Query "Difference between UB and Programming Error" returns concept distinctions

## 3. REQUIRED TOOLS

**Libraries** (add to project):
- `chromadb` or `faiss-cpu` - Vector database
- `sentence-transformers` - Local embeddings (optional, can use OpenAI)
- `openai` - Already used in project for LLM API
- `numpy` - Vector operations

**Reference Files**:
- Read `agents/digestor.py` - Understand how the project uses LLM APIs
- Read `agents/reasoner.py` - Understand the CISB analysis context
- Read `README.md` - Understand project structure and CISB concepts
- Read `Scheme.md` - Understand the 4-phase RAG plan

## 4. MUST DO

1. **Knowledge Document Creation**:
   - Extract CISB definition from project context (README, AGENTS.md, existing prompts)
   - Create structured markdown files in `rag/knowledge_base/`
   - Each document should be 500-2000 words with clear headers

2. **Vector Store Implementation** (`rag/vector_store.py`):
   - Use ChromaDB (simpler) or FAISS (faster)
   - Support: `add_documents(docs: List[str], ids: List[str], metadatas: List[dict])`
   - Support: `query(query: str, top_k: int = 3) -> List[dict]`
   - Persist vector store to disk (e.g., `rag/vector_db/`)

3. **Embedder Implementation** (`rag/embedder.py`):
   - Interface: `embed(texts: List[str]) -> List[List[float]]`
   - Option A: Use OpenAI `text-embedding-3-small` (requires API key)
   - Option B: Use `sentence-transformers/all-MiniLM-L6-v2` (local, free)
   - Default to local embeddings for PoC (no API costs)

4. **Retriever Implementation** (`rag/retriever.py`):
   - Interface: `retrieve(query: str, top_k: int = 3) -> List[str]`
   - Returns document contents (not just IDs)
   - Include metadata (source file, section headers)

5. **Test Script** (`rag/test_rag.py`):
   - Initialize vector store with knowledge documents
   - Run test queries:
     - "What is the definition of CISB?"
     - "Explain Implicit Specification"
     - "What is the difference between Undefined Behavior and Programming Error?"
   - Print retrieved context for each query
   - Verify relevance of retrieved documents

6. **Integration with Existing Pipeline** (optional but recommended):
   - Show how RAG could enhance `agents/reasoner.py`
   - Add example: before reasoning, retrieve relevant CISB concepts

## 5. MUST NOT DO

- Do NOT modify existing agent code (`agents/digestor.py`, `agents/reasoner.py`) - only create new RAG module
- Do NOT add complex features like hybrid search, re-ranking, or query expansion for this PoC
- Do NOT require external services beyond OpenAI (which project already uses) - prefer local embeddings
- Do NOT create a web UI or API server - keep it as a Python module
- Do NOT exceed 1000 lines of code for the entire PoC
- Do NOT use `__init__.py` files if following the project's no-package structure (check AGENTS.md)

## 6. CONTEXT

### Project Structure
```
cisb-llm/
├── agents/           # Existing multi-agent pipeline
├── datasets/         # Bug report data
├── results/          # Evaluation criteria
├── rag/             # [NEW] RAG module (create this)
└── ...
```

### CISB Key Concepts (from README and prompts)

**CISB Definition**:
Compiler-Introduced Security Bugs (CISB) are security vulnerabilities that arise when compiler optimizations change the semantics of source code in ways that introduce security flaws. The bug must:
1. Only manifest with specific optimization flags enabled
2. Represent a semantic deviation from source code intent
3. Have security implications (not just functional bugs)

**Key Distinctions**:
- **Default Behavior**: Compiler assumptions (inlining, type promotion, assuming function must return)
- **Programming Error**: Explicit language spec violations (NOT CISB)
- **Undefined Behavior (UB)**: Standard imposes no requirements; UB with security implications without compiler may be programming error
- **Environment Assumption**: Platform-specific behaviors

**Implicit Specification** (Chapter 3):
Compiler optimizations based on assumptions about code behavior (e.g., no signed overflow, no null pointer dereference)

**Orthogonal Specification** (Chapters 4-5):
Security properties that should hold regardless of optimization level

### Existing Code Patterns

From `agents/agent.py`:
- Uses OpenAI SDK with configurable `base_url`
- Supports both streaming and non-streaming
- API keys stored in `if __name__ == "__main__"` blocks

From `agents/reasoner.py`:
- Chain-of-thought reasoning for CISB detection
- Could benefit from RAG for concept definitions

### Dependencies

Project uses bare imports (no `__init__.py`). Check if RAG should follow same pattern or use proper package structure.

---

## Implementation Notes

**Phase 1 Goal**: Demonstrate that RAG can retrieve relevant CISB knowledge to support the Reasoner agent's classification task.

**Success Criteria**:
1. Vector store successfully indexes all knowledge documents
2. Queries return semantically relevant documents
3. Retrieved context can be injected into prompts
4. Test script runs end-to-end without errors

**Next Steps** (after this PoC):
- Phase 2: Add C language standard and compiler manual content
- Phase 3: Add hardware, microarchitecture, cryptography specs
- Phase 4: Agent-based RAG with knowledge graph
