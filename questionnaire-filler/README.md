# Security Questionnaire Filler

Fills in vendor/customer security questionnaires (spreadsheets) automatically,
using Claude grounded in a local folder of your own security documentation
(policies, past questionnaire answers, compliance reports).

For each question, it retrieves the most relevant document excerpts with a
lexical (BM25) search — no embedding API or vector database required — and
asks Claude to answer using only those excerpts, via the Claude API's
[citations](https://platform.claude.com/docs/en/build-with-claude/citations)
feature, so every part of the answer can be traced back to a specific source
document.

Questions with no supporting documentation, or ones Claude declines to
answer, are flagged in a `Needs Review` column rather than silently guessed.

## Setup

```
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

Authenticate with the Anthropic API — either run `ant auth login` (the SDK
picks this up automatically), or copy `.env.example` to `.env` and set
`ANTHROPIC_API_KEY`.

## Usage

```
python -m questionnaire_filler.cli \
  --input sample_questionnaire.csv \
  --docs sample_docs \
  --output answered.csv
```

Supported questionnaire formats: `.csv`, `.xlsx`. Supported document formats
in `--docs`: `.txt`, `.md`, `.pdf`, `.docx`.

Options:

| Flag | Default | Meaning |
| --- | --- | --- |
| `--question-column` | auto-detected (first column with "question" in its name) | Override if auto-detection picks the wrong column |
| `--model` | `claude-opus-4-8` | Claude model to use |
| `--effort` | `medium` | Reasoning effort (`low`/`medium`/`high`/`xhigh`/`max`) — raise for nuanced/ambiguous questionnaires, lower for cost/speed on large batches |
| `--top-k` | `5` | Number of document chunks retrieved per question |
| `--chunk-size` | `1500` | Max characters per document chunk before splitting |

The output spreadsheet gets three new columns: `Answer`, `Sources` (which
source document(s) backed the answer), and `Needs Review` (`yes` when the
answer was flagged as insufficiently supported, refused by the model, or hit
an API error).

## Running tests

```
pip install pytest
pytest
```

Tests mock the Anthropic client, so they run without network access or an
API key.

## Notes on the approach

- **Retrieval is lexical (BM25), not embeddings.** This keeps the tool
  self-contained (no embedding provider, no vector DB) at the cost of missing
  purely semantic matches with no shared vocabulary. If retrieval quality is
  too low on your document set, the fix is usually to lower `--chunk-size` or
  increase `--top-k`, not to add an embedding step.
- **Grounding is enforced via citations, not just prompting.** Retrieved
  chunks are passed as `document` content blocks with `citations: {enabled:
  true}`, so citation data comes from the API's own attribution of response
  text to source excerpts, not from asking the model to self-report sources.
- Always have a human review flagged rows before submitting a questionnaire —
  this tool accelerates drafting, it does not replace sign-off.
