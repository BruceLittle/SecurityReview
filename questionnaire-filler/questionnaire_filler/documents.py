"""Load and chunk documents from a local repository folder."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

SUPPORTED_EXTENSIONS = {".txt", ".md", ".pdf", ".docx"}


@dataclass
class Chunk:
    doc_title: str
    doc_path: str
    chunk_index: int
    text: str


def _read_txt(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def _read_pdf(path: Path) -> str:
    from pypdf import PdfReader

    reader = PdfReader(str(path))
    return "\n".join(page.extract_text() or "" for page in reader.pages)


def _read_docx(path: Path) -> str:
    import docx

    doc = docx.Document(str(path))
    return "\n".join(p.text for p in doc.paragraphs)


def _extract_text(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix in (".txt", ".md"):
        return _read_txt(path)
    if suffix == ".pdf":
        return _read_pdf(path)
    if suffix == ".docx":
        return _read_docx(path)
    raise ValueError(f"Unsupported document type: {path}")


def load_and_chunk_documents(
    docs_dir: Path, chunk_size: int = 1500, overlap: int = 200
) -> list[Chunk]:
    """Read every supported file under docs_dir and split it into overlapping chunks."""
    chunks: list[Chunk] = []
    paths = sorted(
        p for p in Path(docs_dir).rglob("*") if p.suffix.lower() in SUPPORTED_EXTENSIONS
    )
    for path in paths:
        text = _extract_text(path).strip()
        if not text:
            continue
        for i, chunk_text in enumerate(_split_text(text, chunk_size, overlap)):
            chunks.append(
                Chunk(
                    doc_title=path.name,
                    doc_path=str(path),
                    chunk_index=i,
                    text=chunk_text,
                )
            )
    return chunks


def _split_text(text: str, chunk_size: int, overlap: int) -> list[str]:
    # Split on paragraph boundaries first so chunks don't cut sentences mid-word,
    # then pack paragraphs into ~chunk_size windows with a character overlap.
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    if not paragraphs:
        return []

    chunks: list[str] = []
    current = ""
    for para in paragraphs:
        if current and len(current) + len(para) + 1 > chunk_size:
            chunks.append(current)
            current = current[-overlap:] if overlap else ""
        current = f"{current}\n{para}".strip() if current else para
    if current:
        chunks.append(current)
    return chunks
