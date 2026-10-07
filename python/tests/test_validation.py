"""Input that used to be modelled silently wrong now raises."""
import numpy as np
import pandas as pd
import pytest

from ena import ENA, accumulate
from ena.rotations import generalized_rotation

CODES = ["A", "B", "C"]


def make_df():
    rng = np.random.default_rng(0)
    n = 40
    return pd.DataFrame({
        "unit":  [f"u{i % 8}" for i in range(n)],
        "convo": [f"c{i // 10}" for i in range(n)],
        "group": [("g1" if i % 8 < 4 else "g2") for i in range(n)],
        **{c: rng.integers(0, 2, n) for c in CODES},
    })


def test_missing_column_is_an_error():
    with pytest.raises(KeyError, match="column\\(s\\) not found in data: Bx"):
        accumulate(make_df(), "unit", "convo", ["A", "Bx", "C"])


def test_codes_as_string_or_duplicated_is_an_error():
    with pytest.raises(ValueError, match="non-empty list"):
        accumulate(make_df(), "unit", "convo", "ABC")
    with pytest.raises(ValueError, match="duplicate"):
        accumulate(make_df(), "unit", "convo", ["A", "A", "B"])


def test_nan_conversation_is_an_error_not_a_dropped_row():
    df = make_df()
    df.loc[3, "convo"] = np.nan
    with pytest.raises(ValueError, match="conversations column\\(s\\) contain missing values"):
        accumulate(df, "unit", "convo", CODES)


def test_nan_unit_is_an_error_not_a_unit_called_nan():
    df = make_df()
    df.loc[5, "unit"] = None
    with pytest.raises(ValueError, match="units column\\(s\\) contain missing values"):
        accumulate(df, "unit", "convo", CODES)


def test_nan_or_text_code_is_an_error():
    df = make_df().astype({"B": "object"})
    df.loc[7, "B"] = np.nan
    with pytest.raises(ValueError, match="code column\\(s\\) contain missing or non-numeric values: B"):
        accumulate(df, "unit", "convo", CODES)
    df.loc[7, "B"] = "yes"
    with pytest.raises(ValueError, match="non-numeric values: B"):
        accumulate(df, "unit", "convo", CODES)


def test_bad_window_sizes_are_errors():
    with pytest.raises(ValueError, match="window_size"):
        accumulate(make_df(), "unit", "convo", CODES, window_size=-1)
    with pytest.raises(ValueError, match="window_forward"):
        accumulate(make_df(), "unit", "convo", CODES, window_forward=1.5)


def test_dims_out_of_range_is_a_clear_error():
    df = make_df()
    with pytest.raises(ValueError, match="dims=20 but the rotation has only"):
        ENA().fit(df, "unit", "convo", CODES, window_size=4, dims=20)
    with pytest.raises(ValueError, match="positive integer"):
        ENA().fit(df, "unit", "convo", CODES, window_size=4, dims=0)


def test_select_2_groups_with_an_unknown_group_is_a_clear_error():
    df = make_df()
    groups = df.drop_duplicates("unit").set_index("unit").loc[sorted(df["unit"].unique()), "group"]
    rot = generalized_rotation(groups.to_numpy(), select_2_groups=("g1", "gX"))
    with pytest.raises(ValueError, match="no units have x_var == 'gX'"):
        rot(np.random.default_rng(1).normal(size=(8, 3)))
