import numpy as np
import pandas as pd
import pytest

from ena import accumulate, ENAAccumulation, ena_space_dist_corr, tune_window_size


def make_df(n=120, n_units=8, n_convos=4, codes=("A", "B", "C", "D"), seed=0):
    rng = np.random.default_rng(seed)
    return pd.DataFrame({
        "unit":  [f"U{i % n_units}" for i in range(n)],
        "convo": [f"C{i % n_convos}" for i in range(n)],
        **{c: rng.integers(0, 2, n).astype(float) for c in codes},
    })


CODES = ["A", "B", "C", "D"]


class TestSpaceDistCorr:
    def test_identical_spaces_corr_is_one(self):
        rng = np.random.default_rng(1)
        P = rng.normal(size=(10, 2))
        assert ena_space_dist_corr(P, P) == pytest.approx(1.0)

    def test_reflection_invariant(self):
        # Distances are invariant to axis flips -> correlation still 1.0
        rng = np.random.default_rng(2)
        P = rng.normal(size=(10, 2))
        assert ena_space_dist_corr(P, P[:, ::-1]) == pytest.approx(1.0)

    def test_rotation_invariant(self):
        rng = np.random.default_rng(3)
        P = rng.normal(size=(12, 2))
        theta = 0.7
        R = np.array([[np.cos(theta), -np.sin(theta)],
                      [np.sin(theta),  np.cos(theta)]])
        assert ena_space_dist_corr(P, P @ R.T) == pytest.approx(1.0)

    def test_mismatched_rows_raises(self):
        with pytest.raises(ValueError):
            ena_space_dist_corr(np.zeros((5, 2)), np.zeros((4, 2)))

    def test_sampled_path_runs(self):
        # Force the sampling branch with a tiny max_sample_size.
        rng = np.random.default_rng(4)
        P = rng.normal(size=(50, 2))
        val = ena_space_dist_corr(P, P, max_sample_size=100, random_state=0)
        assert val == pytest.approx(1.0)


class TestTuneWindowSize:
    def test_returns_accumulation_at_selected_window(self):
        df = make_df()
        accum = accumulate(df, "unit", "convo", CODES, window_size=4)
        tuned = tune_window_size(accum, min_size=1, max_size=6, cutoff=0.95)
        assert isinstance(tuned, ENAAccumulation)
        w = tuned.source_call["window_size"]
        assert 1 <= w <= 6

    def test_source_call_is_stored(self):
        df = make_df()
        accum = accumulate(df, "unit", "convo", CODES, window_size=3)
        assert accum.source_call is not None
        assert accum.source_call["window_size"] == 3
        assert accum.source_call["codes"] == CODES

    def test_requires_source_call(self):
        bare = ENAAccumulation(
            networks=np.zeros((2, 1)), units=["U0", "U1"],
            codes=["A", "B"], connection_names=["A & B"],
            meta=pd.DataFrame(index=["U0", "U1"]),
        )
        with pytest.raises(ValueError):
            tune_window_size(bare)

    def test_requires_at_least_two_windows(self):
        df = make_df()
        accum = accumulate(df, "unit", "convo", CODES)
        with pytest.raises(ValueError):
            tune_window_size(accum, min_size=3, max_size=3)
