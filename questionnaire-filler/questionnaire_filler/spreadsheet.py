"""Read a questionnaire spreadsheet, and write it back with answer columns filled in."""

from __future__ import annotations

from pathlib import Path

import pandas as pd

ANSWER_COLUMN = "Answer"
SOURCES_COLUMN = "Sources"
NEEDS_REVIEW_COLUMN = "Needs Review"


def load_questionnaire(path: Path) -> pd.DataFrame:
    suffix = Path(path).suffix.lower()
    if suffix == ".csv":
        return pd.read_csv(path, dtype=str, keep_default_na=False)
    if suffix in (".xlsx", ".xls"):
        return pd.read_excel(path, dtype=str)
    raise ValueError(f"Unsupported questionnaire format: {suffix}")


def save_questionnaire(df: pd.DataFrame, path: Path) -> None:
    suffix = Path(path).suffix.lower()
    if suffix == ".csv":
        df.to_csv(path, index=False)
    elif suffix in (".xlsx", ".xls"):
        df.to_excel(path, index=False)
    else:
        raise ValueError(f"Unsupported output format: {suffix}")


def find_question_column(df: pd.DataFrame, explicit: str | None = None) -> str:
    if explicit:
        if explicit not in df.columns:
            raise ValueError(f"Column '{explicit}' not found. Available: {list(df.columns)}")
        return explicit
    for col in df.columns:
        if "question" in col.lower():
            return col
    raise ValueError(
        f"Could not auto-detect a question column. Available columns: {list(df.columns)}. "
        "Pass --question-column explicitly."
    )


def ensure_output_columns(df: pd.DataFrame) -> pd.DataFrame:
    for col in (ANSWER_COLUMN, SOURCES_COLUMN, NEEDS_REVIEW_COLUMN):
        if col not in df.columns:
            df[col] = ""
    return df
