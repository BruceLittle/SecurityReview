"""CLI entrypoint: fill a security questionnaire spreadsheet using a local doc repository."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import anthropic
from dotenv import load_dotenv
from tqdm import tqdm

from questionnaire_filler.claude_answerer import DEFAULT_MODEL, answer_question
from questionnaire_filler.documents import load_and_chunk_documents
from questionnaire_filler.retriever import Retriever
from questionnaire_filler.spreadsheet import (
    ANSWER_COLUMN,
    NEEDS_REVIEW_COLUMN,
    SOURCES_COLUMN,
    ensure_output_columns,
    find_question_column,
    load_questionnaire,
    save_questionnaire,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Questionnaire file (.xlsx/.csv)")
    parser.add_argument("--docs", required=True, type=Path, help="Folder of source documents")
    parser.add_argument("--output", required=True, type=Path, help="Where to write the filled questionnaire")
    parser.add_argument("--question-column", default=None, help="Override auto-detected question column")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"Claude model ID (default: {DEFAULT_MODEL})")
    parser.add_argument(
        "--effort",
        default="medium",
        choices=["low", "medium", "high", "xhigh", "max"],
        help="Reasoning effort per question (default: medium)",
    )
    parser.add_argument("--top-k", type=int, default=5, help="Chunks retrieved per question (default: 5)")
    parser.add_argument("--chunk-size", type=int, default=1500, help="Max characters per document chunk")
    return parser


def run(args: argparse.Namespace) -> int:
    load_dotenv()

    if not args.docs.is_dir():
        print(f"Document folder not found: {args.docs}", file=sys.stderr)
        return 1

    chunks = load_and_chunk_documents(args.docs, chunk_size=args.chunk_size)
    if not chunks:
        print(f"No supported documents found under {args.docs}", file=sys.stderr)
        return 1
    print(f"Indexed {len(chunks)} chunks from {args.docs}")

    retriever = Retriever(chunks)
    client = anthropic.Anthropic()

    df = load_questionnaire(args.input)
    question_col = find_question_column(df, args.question_column)
    df = ensure_output_columns(df)

    for idx, row in tqdm(df.iterrows(), total=len(df), desc="Answering"):
        question = str(row[question_col]).strip()
        if not question:
            continue

        top_chunks = retriever.top_chunks(question, k=args.top_k)
        result = answer_question(
            client, question, top_chunks, model=args.model, effort=args.effort
        )

        if result.error and ("credentials" in result.error.lower() or "authentication" in result.error.lower()):
            print(
                f"\nStopping: Claude API credentials are not configured ({result.error}).\n"
                "Set ANTHROPIC_API_KEY (see .env.example) or run `ant auth login`, then retry.",
                file=sys.stderr,
            )
            return 1

        df.at[idx, ANSWER_COLUMN] = result.answer_text if not result.error else f"ERROR: {result.error}"
        df.at[idx, SOURCES_COLUMN] = "; ".join(result.source_titles)
        df.at[idx, NEEDS_REVIEW_COLUMN] = "yes" if (result.needs_review or result.error) else ""

    save_questionnaire(df, args.output)
    flagged = int((df[NEEDS_REVIEW_COLUMN] == "yes").sum())
    print(f"Wrote {args.output}. {flagged} of {len(df)} answers flagged for manual review.")
    return 0


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    sys.exit(run(args))


if __name__ == "__main__":
    main()
