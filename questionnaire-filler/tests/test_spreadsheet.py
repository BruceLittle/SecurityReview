from pathlib import Path

from questionnaire_filler.spreadsheet import (
    ensure_output_columns,
    find_question_column,
    load_questionnaire,
    save_questionnaire,
)


def test_load_and_detect_question_column():
    path = Path(__file__).parent.parent / "sample_questionnaire.csv"
    df = load_questionnaire(path)
    col = find_question_column(df)
    assert col == "Question"
    assert len(df) == 4


def test_ensure_output_columns_adds_missing_columns():
    path = Path(__file__).parent.parent / "sample_questionnaire.csv"
    df = load_questionnaire(path)
    df = ensure_output_columns(df)
    assert set(["Answer", "Sources", "Needs Review"]).issubset(df.columns)


def test_round_trip_csv(tmp_path):
    path = Path(__file__).parent.parent / "sample_questionnaire.csv"
    df = ensure_output_columns(load_questionnaire(path))
    df.at[0, "Answer"] = "test answer"

    out_path = tmp_path / "out.csv"
    save_questionnaire(df, out_path)

    reloaded = load_questionnaire(out_path)
    assert reloaded.at[0, "Answer"] == "test answer"
