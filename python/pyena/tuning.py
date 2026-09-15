"""
pyena.tuning — Window-size tuning for ENA accumulation.

Port of rENA's ``ena.tune.window.size`` / ``ena_space_dist_corr``.

The idea: an ENA model's structure stabilises as the stanza window grows.
Rebuilding the accumulation across a range of window sizes and correlating the
pairwise unit-distance geometry of adjacent sizes reveals a "stability plateau".
The smallest window whose adjacent correlation reaches ``cutoff`` of the maximum
observed correlation is chosen as the tuned window size.

    from pyena import accumulate, tune_window_size

    accum = accumulate(rs, "unit_key", "convo_key", CODES, window_size=4)
    tuned = tune_window_size(accum, min_size=1, max_size=20, cutoff=0.95)
    tuned.source_call["window_size"]   # the selected window size
"""

from __future__ import annotations

import warnings
from dataclasses import dataclass
from typing import List, Optional, Union

import numpy as np
import pandas as pd

from pylibqe import ccd as _ccd_kernel

from .accumulation import ENAAccumulation, accumulate


# ── distance-space correlation ────────────────────────────────────────────────

def ena_space_dist_corr(
    A: np.ndarray,
    B: np.ndarray,
    max_sample_size: int = 100_000,
    random_state: Optional[Union[int, np.random.Generator]] = None,
) -> float:
    """Pearson correlation between the pairwise distances of two ENA spaces.

    Computes the Euclidean distance between every pair of points within ``A``
    and within ``B`` (using the *same* pairing for both), then returns the
    Pearson correlation of the two distance vectors.  Because pairwise
    distances are invariant to rotation/reflection of a space, this measures
    how similar the two point configurations are up to an orthogonal transform
    — exactly what is needed to compare ENA solutions across window sizes,
    whose SVD axes may otherwise flip sign.

    Mirrors R's :func:`ena_space_dist_corr`: exact for small spaces, sampled
    (with replacement, self-pairs dropped) once the number of unique pairs
    exceeds ``max_sample_size``.

    Parameters
    ----------
    A, B : np.ndarray
        Point matrices (rows are points).  Must share the same number of rows.
    max_sample_size : int
        Maximum number of pairwise distances to compute before switching to
        sampling.  Default 100,000.
    random_state : int | np.random.Generator | None
        Seed or generator for the sampled path (ignored on the exact path).

    Returns
    -------
    float
        Pearson correlation of the paired distance vectors.
    """
    A = np.ascontiguousarray(A, dtype=np.float64)
    B = np.ascontiguousarray(B, dtype=np.float64)
    m = A.shape[0]

    if m == 0 or B.shape[0] != m:
        raise ValueError("The spaces must have the same non-zero number of rows.")

    total_possible_pairs = m * (m - 1) // 2

    if total_possible_pairs <= max_sample_size:
        # Exact: all unique i<j pairs.
        i, j = np.triu_indices(m, k=1)
        dist_a = np.linalg.norm(A[i] - A[j], axis=1)
        dist_b = np.linalg.norm(B[i] - B[j], axis=1)
    else:
        # Sample pairs with replacement, drop self-pairs (matches R).
        rng = (random_state if isinstance(random_state, np.random.Generator)
               else np.random.default_rng(random_state))
        idx1 = rng.integers(0, m, size=max_sample_size)
        idx2 = rng.integers(0, m, size=max_sample_size)
        keep = idx1 != idx2
        idx1, idx2 = idx1[keep], idx2[keep]
        dist_a = np.linalg.norm(A[idx1] - A[idx2], axis=1)
        dist_b = np.linalg.norm(B[idx1] - B[idx2], axis=1)

    return float(np.corrcoef(dist_a, dist_b)[0, 1])


# ── window-size tuning ─────────────────────────────────────────────────────────

def tune_window_size(
    accum: ENAAccumulation,
    min_size: int = 1,
    max_size: int = 20,
    cutoff: float = 0.95,
) -> ENAAccumulation:
    """Find the stability-plateau window size and rebuild the accumulation there.

    Iterates the stanza window from ``min_size`` to ``max_size``, rebuilding the
    accumulation and fitting a default (SVD) ENA model at each size.  Adjacent
    window sizes are compared with :func:`ena_space_dist_corr` on their unit
    points; the smallest window whose adjacent correlation reaches
    ``cutoff * max(correlation)`` is selected.

    Parameters
    ----------
    accum : ENAAccumulation
        An accumulation produced by :func:`pyena.accumulate`.  Its
        ``source_call`` is used to rebuild at each window size — pass an object
        built via :func:`accumulate` (not one constructed directly).
    min_size : int
        Smallest window size to test (default 1).
    max_size : int
        Largest window size to test (default 20).
    cutoff : float
        Fraction of the maximum adjacent correlation used as the selection
        threshold (default 0.95).

    Returns
    -------
    ENAAccumulation
        A new accumulation rebuilt at the selected window size (mirrors R,
        which returns the rebuilt object).  The chosen size is available as
        ``result.source_call["window_size"]``.
    """
    call = getattr(accum, "source_call", None)
    if call is None:
        raise ValueError(
            "accum has no stored source_call; build it with pyena.accumulate() "
            "to enable window-size tuning."
        )

    window_range = list(range(min_size, max_size + 1))
    if len(window_range) < 2:
        raise ValueError("max_size must be greater than min_size to compare windows.")

    # Imported here to avoid a circular import (ena.py imports accumulation).
    from .ena import ENA

    # 1. Rebuild + fit at each window size, collecting the unit points.
    all_points = []
    for window_size in window_range:
        new_accum = accumulate(
            call["data"], call["units"], call["conversations"], call["codes"],
            window_size=window_size,
            window_forward=call["window_forward"],
            binary=call["binary"],
        )
        model = ENA().fit(new_accum)
        all_points.append(model.points_)

    # 2. Adjacent-window distance-space correlations.
    adj_correlations = np.array([
        ena_space_dist_corr(all_points[i], all_points[i + 1])
        for i in range(len(window_range) - 1)
    ])

    # 3. Smallest window crossing cutoff * max correlation.
    max_corr = np.nanmax(adj_correlations)
    threshold = cutoff * max_corr
    crossers = np.where(adj_correlations >= threshold)[0]
    best_idx = int(crossers[0]) if crossers.size else 0
    best_window_size = window_range[best_idx]

    # 4. Rebuild the accumulation at the selected window size.
    return accumulate(
        call["data"], call["units"], call["conversations"], call["codes"],
        window_size=best_window_size,
        window_forward=call["window_forward"],
        binary=call["binary"],
    )


# ── cross-covariance decay (CCD) window-size estimation ────────────────────────

@dataclass
class CCDResult:
    """Result of a cross-covariance decay window-size estimation.

    Mirrors R's ``ena.ccd`` S3 object.
    """

    window_size: int
    peak_lag: int
    curves: pd.DataFrame          # lag, frob, frob_sq_unbiased, frob_unbiased_signed, total_weight
    codes: List[str]
    conversation_cols: List[str]

    def __repr__(self) -> str:  # pragma: no cover - cosmetic
        return (f"<CCDResult window_size={self.window_size} "
                f"peak_lag={self.peak_lag} codes={len(self.codes)}>")


def ccd(
    data: pd.DataFrame,
    codes: List[str],
    conversation_cols: Union[str, List[str]],
    max_window: int = 20,
    min_overlap: int = 10,
) -> CCDResult:
    """Estimate the ENA moving-window size via Cross-Covariance Decay (CCD).

    Port of rENA's ``ena.ccd``. Splits the data into conversations, then defers
    the numeric core (pooled cross-covariance curves + half-life detection) to
    the shared libqe kernel ``pylibqe.ccd.ccd_window`` — the same kernel used by
    the R and WASM builds — so all three surfaces produce identical results.

    Unlike :func:`tune_window_size`, CCD runs directly on the raw code matrix
    per conversation (no accumulation/rotation).

    Parameters
    ----------
    data : pd.DataFrame
        Raw coded data, one row per line.
    codes : list[str]
        Binary code column names.
    conversation_cols : str | list[str]
        Column(s) whose values segment the data into conversations.
    max_window : int
        Maximum lag to evaluate (default 20).
    min_overlap : int
        Minimum overlapping rows (N - lag) required for a conversation to
        contribute at a given lag (default 10).

    Returns
    -------
    CCDResult
    """
    if isinstance(conversation_cols, str):
        conversation_cols = [conversation_cols]
    conversation_cols = list(conversation_cols)
    codes = list(codes)

    missing = [c for c in (*conversation_cols, *codes) if c not in data.columns]
    if missing:
        raise KeyError(f"columns not found in data: {missing}")

    # Numeric code matrix (NA -> 0), aligned to data's rows.
    code_mat = data[codes].apply(pd.to_numeric, errors="coerce").fillna(0.0)

    # Split into conversation subsets, preserving row order; drop subsets shorter
    # than min_overlap (they can never contribute at lag 0).
    grouper = data.groupby(conversation_cols, sort=False, observed=True)
    subsets = []
    for positions in grouper.indices.values():
        if len(positions) < min_overlap:
            continue
        arr = code_mat.iloc[positions].to_numpy(dtype=np.float64)
        subsets.append(np.ascontiguousarray(arr))

    if not subsets:
        warnings.warn(
            f"No conversation subsets had length >= min_overlap ({min_overlap}). "
            "Returning window size = 1."
        )

    kern = _ccd_kernel.ccd_window(subsets, max_window, min_overlap)

    curves = pd.DataFrame({
        "lag":                  kern["lag"],
        "frob":                 kern["frob"],
        "frob_sq_unbiased":     kern["frob_sq_unbiased"],
        "frob_unbiased_signed": kern["frob_unbiased_signed"],
        "total_weight":         kern["total_weight"],
    })

    peak_lag = int(kern["peak_lag"])
    # Mirror R's informational warnings (the window size itself comes from the kernel).
    if subsets:
        f = curves["frob_unbiased_signed"].to_numpy()
        lag = curves["lag"].to_numpy()
        if peak_lag == 0:
            warnings.warn(
                "Corrected Cross Covariance is non-positive or all NA across "
                "evaluated lags. Defaulting to window size = 1."
            )
        else:
            max_f = f[lag == peak_lag][0]
            after = lag >= peak_lag
            ratios = f[after] / max_f
            if not np.any(ratios <= 0.5):
                warnings.warn(
                    "Cross-covariance did not decay below half-life (50%) within "
                    f"max_window = {max_window}."
                )

    return CCDResult(
        window_size=int(kern["window_size"]),
        peak_lag=peak_lag,
        curves=curves,
        codes=codes,
        conversation_cols=conversation_cols,
    )


def ccd_window(
    data: pd.DataFrame,
    codes: List[str],
    conversation_cols: Union[str, List[str]],
    max_window: int = 20,
    min_overlap: int = 10,
) -> int:
    """Estimated CCD window size only (port of R's ``ena.ccd.window``).

    See :func:`ccd` for parameters.
    """
    return ccd(data, codes, conversation_cols,
               max_window=max_window, min_overlap=min_overlap).window_size
