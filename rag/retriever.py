import os
from vector_store import VectorStore


class Retriever:
    """
    RAG retrieval logic: loads knowledge base documents, indexes them
    in a vector store, and retrieves relevant context for queries.

    Member variables:
        vector_store (VectorStore): The underlying vector store.
        knowledge_base_path (str): Path to the knowledge base directory.
    """

    def __init__(self, embedder, knowledge_base_path=None, db_path=None):
        if knowledge_base_path is None:
            knowledge_base_path = os.path.join(
                os.path.dirname(__file__), "knowledge_base"
            )
        self.knowledge_base_path = knowledge_base_path
        self.vector_store = VectorStore(embedder=embedder, db_path=db_path)

    def _split_by_sections(self, text, source_file):
        sections = []
        current_header = source_file
        current_lines = []

        for line in text.split("\n"):
            if line.startswith("## "):
                if current_lines:
                    content = "\n".join(current_lines).strip()
                    if content:
                        sections.append(
                            {
                                "content": content,
                                "header": current_header,
                                "source": source_file,
                            }
                        )
                current_header = line.lstrip("# ").strip()
                current_lines = [line]
            else:
                current_lines.append(line)

        if current_lines:
            content = "\n".join(current_lines).strip()
            if content:
                sections.append(
                    {
                        "content": content,
                        "header": current_header,
                        "source": source_file,
                    }
                )

        return sections

    def ingest_knowledge_base(self):
        self.vector_store.reset()

        all_docs = []
        all_ids = []
        all_metadatas = []

        for filename in sorted(os.listdir(self.knowledge_base_path)):
            if not filename.endswith(".md"):
                continue

            filepath = os.path.join(self.knowledge_base_path, filename)
            with open(filepath, "r", encoding="utf-8") as f:
                text = f.read()

            sections = self._split_by_sections(text, filename)
            for i, section in enumerate(sections):
                all_docs.append(section["content"])
                all_ids.append(f"{filename}_{i}")
                all_metadatas.append(
                    {
                        "source": section["source"],
                        "header": section["header"],
                    }
                )

        if all_docs:
            self.vector_store.add_documents(
                docs=all_docs,
                ids=all_ids,
                metadatas=all_metadatas,
            )

        return len(all_docs)

    def retrieve(self, query, top_k=3):
        """
        Retrieve relevant document sections for a query.

        Returns list of dicts with: content, source, header, distance.
        """
        results = self.vector_store.query(query, top_k=top_k)

        return [
            {
                "content": r["document"],
                "source": r["metadata"]["source"] if r["metadata"] else None,
                "header": r["metadata"]["header"] if r["metadata"] else None,
                "distance": r["distance"],
            }
            for r in results
        ]

    def retrieve_as_context(self, query, top_k=3):
        """
        Retrieve relevant context formatted for prompt injection.

        Returns a single string with retrieved sections separated by
        dividers, suitable for inserting into an LLM system prompt.
        """
        results = self.retrieve(query, top_k=top_k)

        if not results:
            return ""

        context_parts = []
        for r in results:
            source_info = f"[Source: {r['source']} > {r['header']}]"
            context_parts.append(f"{source_info}\n{r['content']}")

        return "\n\n---\n\n".join(context_parts)


if __name__ == "__main__":
    from embedder import Embedder

    API_KEY = ""
    BASE_URL = ""
    MODEL_NAME = ""

    embedder = Embedder(api_key=API_KEY, base_url=BASE_URL, model_name=MODEL_NAME)
    retriever = Retriever(embedder=embedder)

    print("Ingesting knowledge base...")
    num_docs = retriever.ingest_knowledge_base()
    print(f"Indexed {num_docs} document sections.\n")

    query = "What is the definition of CISB?"
    print(f"Query: {query}")
    results = retriever.retrieve(query, top_k=2)
    for r in results:
        print(f"  [{r['source']} > {r['header']}] (distance: {r['distance']:.4f})")
        print(f"    {r['content'][:120]}...")
        print()
