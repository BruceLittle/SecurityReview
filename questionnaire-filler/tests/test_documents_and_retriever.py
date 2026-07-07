from pathlib import Path

from questionnaire_filler.documents import load_and_chunk_documents
from questionnaire_filler.retriever import Retriever


def test_load_and_chunk_sample_docs():
    docs_dir = Path(__file__).parent.parent / "sample_docs"
    chunks = load_and_chunk_documents(docs_dir, chunk_size=500)
    assert chunks
    assert all(c.text.strip() for c in chunks)
    titles = {c.doc_title for c in chunks}
    assert "encryption_policy.md" in titles
    assert "access_control_policy.md" in titles


def test_retriever_ranks_relevant_chunk_first():
    docs_dir = Path(__file__).parent.parent / "sample_docs"
    chunks = load_and_chunk_documents(docs_dir, chunk_size=1500)
    retriever = Retriever(chunks)

    results = retriever.top_chunks("Is data encrypted at rest with AES-256?", k=3)
    assert results
    assert results[0].doc_title == "encryption_policy.md"


def test_retriever_returns_empty_for_unrelated_query():
    docs_dir = Path(__file__).parent.parent / "sample_docs"
    chunks = load_and_chunk_documents(docs_dir, chunk_size=1500)
    retriever = Retriever(chunks)

    results = retriever.top_chunks("zzz completely unrelated nonsense query qqq", k=3)
    assert results == []
