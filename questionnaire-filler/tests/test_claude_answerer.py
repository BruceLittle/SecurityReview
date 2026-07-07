from dataclasses import dataclass, field

from questionnaire_filler.claude_answerer import answer_question
from questionnaire_filler.documents import Chunk


@dataclass
class FakeCitation:
    cited_text: str
    document_title: str


@dataclass
class FakeTextBlock:
    text: str
    citations: list = field(default_factory=list)
    type: str = "text"


@dataclass
class FakeResponse:
    content: list
    stop_reason: str = "end_turn"


class FakeMessages:
    def __init__(self, response):
        self._response = response

    def create(self, **kwargs):
        return self._response


class FakeClient:
    def __init__(self, response):
        self.messages = FakeMessages(response)


def _sample_chunks():
    return [Chunk(doc_title="encryption_policy.md", doc_path="/x", chunk_index=0, text="AES-256 at rest.")]


def test_answer_question_extracts_text_and_citations():
    response = FakeResponse(
        content=[
            FakeTextBlock(
                text="Yes, data is encrypted with AES-256.",
                citations=[FakeCitation(cited_text="AES-256 at rest.", document_title="encryption_policy.md")],
            )
        ]
    )
    client = FakeClient(response)

    result = answer_question(client, "Is data encrypted?", _sample_chunks())

    assert result.answer_text == "Yes, data is encrypted with AES-256."
    assert result.source_titles == ["encryption_policy.md"]
    assert not result.needs_review
    assert result.error is None


def test_answer_question_flags_insufficient_information():
    response = FakeResponse(
        content=[FakeTextBlock(text="INSUFFICIENT INFORMATION: no relevant documentation found.")]
    )
    client = FakeClient(response)

    result = answer_question(client, "Do you use quantum encryption?", _sample_chunks())

    assert result.needs_review is True


def test_answer_question_with_no_chunks_skips_api_call():
    result = answer_question(FakeClient(FakeResponse(content=[])), "Unanswerable question", [])

    assert result.needs_review is True
    assert "INSUFFICIENT INFORMATION" in result.answer_text


def test_answer_question_handles_refusal_stop_reason():
    response = FakeResponse(content=[], stop_reason="refusal")
    client = FakeClient(response)

    result = answer_question(client, "Some question", _sample_chunks())

    assert result.needs_review is True
    assert "refusal" in result.error


class FakeMessagesRaisesTypeError:
    def create(self, **kwargs):
        # Mirrors the real SDK: missing credentials surface as a plain TypeError
        # raised while building the request, not an anthropic.* exception.
        raise TypeError("Could not resolve authentication method.")


class FakeClientMissingCredentials:
    def __init__(self):
        self.messages = FakeMessagesRaisesTypeError()


def test_answer_question_does_not_crash_on_missing_credentials():
    result = answer_question(FakeClientMissingCredentials(), "Some question", _sample_chunks())

    assert result.needs_review is True
    assert "authentication" in result.error.lower()
