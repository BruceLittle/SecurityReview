"""Calls the Claude Messages API to answer one questionnaire question, grounded in
retrieved document chunks via the citations feature (no separate RAG/embedding step —
the retriever supplies candidate chunks, and Claude's citations tie each part of the
answer back to a specific source chunk)."""

from __future__ import annotations

from dataclasses import dataclass, field

import anthropic

from questionnaire_filler.documents import Chunk

DEFAULT_MODEL = "claude-opus-4-8"

SYSTEM_PROMPT = """\
You are answering vendor/customer security questionnaires on behalf of our company.

You will be given several excerpts from our internal security documentation
(policies, past questionnaire answers, compliance reports), each as a separate
document, followed by one questionnaire question.

Rules:
- Answer using ONLY the provided document excerpts. Do not use outside knowledge
  or make assumptions about our systems, controls, or practices.
- If the excerpts fully answer the question, give a direct, complete answer suitable
  for pasting into a vendor questionnaire response field.
- If the excerpts only partially answer the question, answer what you can and
  explicitly state what is missing.
- If the excerpts contain nothing relevant, respond with exactly:
  "INSUFFICIENT INFORMATION: no relevant documentation found." and nothing else.
- Be concise and factual. Do not editorialize or add disclaimers beyond what the
  rules above require.
"""


@dataclass
class Citation:
    cited_text: str
    document_title: str | None


@dataclass
class AnsweredQuestion:
    question: str
    answer_text: str
    citations: list[Citation] = field(default_factory=list)
    source_titles: list[str] = field(default_factory=list)
    needs_review: bool = False
    error: str | None = None


def _build_content_blocks(question: str, chunks: list[Chunk]) -> list[dict]:
    blocks: list[dict] = []
    for chunk in chunks:
        blocks.append(
            {
                "type": "document",
                "source": {
                    "type": "text",
                    "media_type": "text/plain",
                    "data": chunk.text,
                },
                "title": chunk.doc_title,
                "citations": {"enabled": True},
            }
        )
    blocks.append({"type": "text", "text": f"Questionnaire question: {question}"})
    return blocks


def answer_question(
    client: anthropic.Anthropic,
    question: str,
    chunks: list[Chunk],
    model: str = DEFAULT_MODEL,
    effort: str = "medium",
    max_tokens: int = 1536,
) -> AnsweredQuestion:
    if not chunks:
        return AnsweredQuestion(
            question=question,
            answer_text="INSUFFICIENT INFORMATION: no relevant documentation found.",
            needs_review=True,
        )

    try:
        response = client.messages.create(
            model=model,
            max_tokens=max_tokens,
            system=SYSTEM_PROMPT,
            output_config={"effort": effort},
            messages=[{"role": "user", "content": _build_content_blocks(question, chunks)}],
        )
    except anthropic.APIStatusError as e:
        return AnsweredQuestion(
            question=question,
            answer_text="",
            needs_review=True,
            error=f"{e.status_code}: {e.message}",
        )
    except anthropic.APIConnectionError as e:
        return AnsweredQuestion(question=question, answer_text="", needs_review=True, error=str(e))

    if response.stop_reason == "refusal":
        return AnsweredQuestion(
            question=question,
            answer_text="",
            needs_review=True,
            error="model declined to answer (refusal)",
        )

    answer_parts: list[str] = []
    citations: list[Citation] = []
    for block in response.content:
        if block.type != "text":
            continue
        answer_parts.append(block.text)
        for cite in getattr(block, "citations", None) or []:
            citations.append(
                Citation(
                    cited_text=getattr(cite, "cited_text", ""),
                    document_title=getattr(cite, "document_title", None),
                )
            )

    source_titles = sorted({c.document_title for c in citations if c.document_title})
    answer_text = "".join(answer_parts).strip()
    needs_review = answer_text.startswith("INSUFFICIENT INFORMATION") or not answer_text

    return AnsweredQuestion(
        question=question,
        answer_text=answer_text,
        citations=citations,
        source_titles=source_titles,
        needs_review=needs_review,
    )
