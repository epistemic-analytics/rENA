"""Tests for Cross-Covariance Decay (CCD) window-size estimation.

Port of R's ena.ccd / ena.ccd.window, backed by the shared libqe kernel
qe.ccd.ccd_window. Verified against R on RS.data (window_size = 6,
peak_lag = 1; curves agree to ~5e-16).
"""

import numpy as np
import pandas as pd
import pytest

from ena import ccd, ccd_window, CCDResult


def make_df(seed=7):
    """Two conversations x 40 rows; code B tends to follow code A at lag 1."""
    rng = np.random.default_rng(seed)
    rows = []
    for conv in ("C1", "C2"):
        prev_a = 0
        for _ in range(40):
            a = 1 if rng.random() < 0.4 else 0
            b = 1 if (prev_a == 1 and rng.random() < 0.8) else (1 if rng.random() < 0.15 else 0)
            c = 1 if rng.random() < 0.3 else 0
            rows.append({"Convo": conv, "A": a, "B": b, "C": c})
            prev_a = a
    return pd.DataFrame(rows)


CODES = ["A", "B", "C"]


class TestCCD:
    def test_returns_ccd_result(self):
        res = ccd(make_df(), CODES, "Convo", max_window=15, min_overlap=5)
        assert isinstance(res, CCDResult)
        assert res.codes == CODES
        assert res.conversation_cols == ["Convo"]

    def test_window_within_range(self):
        res = ccd(make_df(), CODES, "Convo", max_window=15, min_overlap=5)
        assert 1 <= res.window_size <= 15
        assert res.peak_lag >= 1

    def test_curves_length_is_max_window_plus_one(self):
        res = ccd(make_df(), CODES, "Convo", max_window=15, min_overlap=5)
        assert len(res.curves) == 16
        assert list(res.curves.columns) == [
            "lag", "frob", "frob_sq_unbiased", "frob_unbiased_signed", "total_weight"
        ]
        assert res.curves["lag"].iloc[0] == 0
        assert res.curves["lag"].iloc[-1] == 15

    def test_ccd_window_matches_result(self):
        df = make_df()
        assert ccd_window(df, CODES, "Convo", max_window=15, min_overlap=5) == \
            ccd(df, CODES, "Convo", max_window=15, min_overlap=5).window_size

    def test_accepts_multiple_conversation_cols(self):
        df = make_df()
        df["Block"] = "B1"
        res = ccd(df, CODES, ["Block", "Convo"], max_window=15, min_overlap=5)
        # Grouping by (Block, Convo) yields the same two conversations as Convo alone.
        assert res.window_size == ccd_window(df, CODES, "Convo", max_window=15, min_overlap=5)

    def test_too_short_conversations_default_to_window_one(self):
        df = pd.DataFrame({
            "Convo": ["c1", "c1", "c1"],
            "A": [1.0, 0.0, 1.0], "B": [0.0, 1.0, 1.0], "C": [1.0, 1.0, 0.0],
        })
        with pytest.warns(UserWarning, match="min_overlap"):
            res = ccd(df, CODES, "Convo", max_window=15, min_overlap=10)
        assert res.window_size == 1
        assert res.peak_lag == 0

    def test_missing_columns_raise(self):
        df = make_df()
        with pytest.raises(KeyError):
            ccd(df, ["A", "B", "NOPE"], "Convo")
        with pytest.raises(KeyError):
            ccd(df, CODES, "Missing")
