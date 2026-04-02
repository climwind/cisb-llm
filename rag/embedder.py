from openai import OpenAI


class Embedder:
    """
    Calls an OpenAI-compatible embedding API to generate text embeddings.

    Member variables:
        model_name (str): Name of the embedding model.
        client (OpenAI): OpenAI-compatible API client.

    Member functions:
        embed(texts) -> list[list[float]]: Generate embeddings for a list of texts.
    """

    def __init__(self, api_key, base_url, model_name):
        self.model_name = model_name
        self.client = OpenAI(api_key=api_key, base_url=base_url)

    def embed(self, texts):
        response = self.client.embeddings.create(
            input=texts,
            model=self.model_name,
        )
        return [item.embedding for item in response.data]


if __name__ == "__main__":
    API_KEY = ""
    BASE_URL = ""
    MODEL_NAME = ""

    embedder = Embedder(api_key=API_KEY, base_url=BASE_URL, model_name=MODEL_NAME)
    test_texts = [
        "What is CISB?",
        "Compiler-Introduced Security Bugs are vulnerabilities from optimizations.",
        "Undefined behavior in C language standard.",
    ]
    results = embedder.embed(test_texts)
    for text, vec in zip(test_texts, results):
        print(f"Text: {text[:50]}...")
        print(f"  Dimension: {len(vec)}")
        print(f"  First 5 values: {vec[:5]}")
        print()
