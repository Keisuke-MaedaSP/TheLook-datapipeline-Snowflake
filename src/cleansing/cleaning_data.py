import hashlib
import pandas as pd

def _validate_columns(df: pd.DataFrame, target_columns: list):
    """指定されたカラムがデータフレーム内に存在するか検証し、存在しない場合のみErrorを発生させる"""
    missing_cols = [col for col in target_columns if col not in df.columns]
    if missing_cols:
        raise KeyError(f"指定されたカラムがデータ内に存在しません: {missing_cols}")


def to_lowercase(df: pd.DataFrame, target_columns: list):
    _validate_columns(df, target_columns)
    for column in target_columns:
        df[column] = df[column].str.lower()
    return df


def to_datetime(df: pd.DataFrame, target_columns: list):
    _validate_columns(df, target_columns)
    for column in target_columns:
        df[column] = pd.to_datetime(
            df[column],
            format="mixed",
            errors="coerce",
            utc=True
        )
    return df


def to_hash(df: pd.DataFrame, target_columns: list):
    _validate_columns(df, target_columns)
    for column in target_columns:
        df[column] = df[column].map(
            lambda value: hashlib.sha256(value.encode("utf-8")).hexdigest(),
            na_action="ignore"
        )
    return df
