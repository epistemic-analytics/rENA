"""
ena.rotations — Rotation factory functions for ENA.

Each factory returns a callable ``rotation_fn(centered) -> np.ndarray`` where:
  - Input  ``centered``: (n_units × n_connections) centered normalised networks
  - Output: (n_connections × n_connections) full orthogonal rotation matrix
    (or as many columns as numerically available; ``ENA.fit`` slices to ``dims``).
"""

from __future__ import annotations

import numpy as np


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

def _deflate(V: np.ndarray, v: np.ndarray) -> np.ndarray:
    """Project direction *v* out of every row of V."""
    v = v / np.linalg.norm(v)
    return V - (V @ v[:, None]) @ v[None, :]


def _gmr(V: np.ndarray, x) -> np.ndarray:
    """
    Core GMR vector.

    Parameters
    ----------
    V : (n_units × n_connections) centered data.
    x : (n_units,) predictor — numeric or categorical.

    Returns
    -------
    (n_connections,) unit vector.
    """
    x = np.asarray(x)

    if np.issubdtype(x.dtype, np.floating) or np.issubdtype(x.dtype, np.integer):
        # Continuous: multivariate OLS V ~ x, take slope coefficients
        x_c = x - x.mean()
        denom = x_c @ x_c
        if denom < 1e-30:
            # degenerate predictor — fall back to first SVD component
            _, _, Vt = np.linalg.svd(V, full_matrices=False)
            return Vt[0]
        beta = (x_c @ V) / denom
        norm = np.linalg.norm(beta)
        return beta / norm if norm > 1e-10 else beta
    else:
        # Categorical: between-group scatter matrix SB → first eigenvector
        SB = _compute_SB(V, x)
        _, vecs = np.linalg.eigh(SB)
        return vecs[:, -1]  # eigenvec for largest eigenvalue


def _compute_SB(V: np.ndarray, labels) -> np.ndarray:
    """Between-group scatter matrix."""
    labels = np.asarray(labels)
    mu_total = V.mean(axis=0)
    n_conn = V.shape[1]
    SB = np.zeros((n_conn, n_conn))
    for grp in np.unique(labels):
        mask = labels == grp
        n_g = mask.sum()
        mu_g = V[mask].mean(axis=0)
        diff = (mu_g - mu_total)[:, None]
        SB += n_g * (diff @ diff.T)
    return SB


def _regression_axis(V: np.ndarray, x) -> np.ndarray:
    """Multivariate OLS V ~ x; return normalised slope vector."""
    x = np.asarray(x, dtype=float)
    X_c = np.column_stack([np.ones(len(x)), x])
    beta, _, _, _ = np.linalg.lstsq(X_c, V, rcond=None)
    v = beta[1]
    norm = np.linalg.norm(v)
    return v / norm if norm > 1e-10 else v


def _regression_axis_2(V: np.ndarray, x) -> np.ndarray:
    """Reversed OLS x ~ V; return normalised slope vector."""
    x = np.asarray(x, dtype=float)
    X_c = np.column_stack([np.ones(len(x)), V])
    beta, _, _, _ = np.linalg.lstsq(X_c, x, rcond=None)
    v = beta[1:]
    norm = np.linalg.norm(v)
    return v / norm if norm > 1e-10 else v


def _orthogonal_svd(centered: np.ndarray, criterion_vecs: np.ndarray) -> np.ndarray:
    """
    Build a full orthogonal rotation matrix from *criterion_vecs*.

    Parameters
    ----------
    centered       : (n_units × n_conn) data matrix.
    criterion_vecs : (n_conn × k) — the k priority axes (already normalised).

    Returns
    -------
    (n_conn × n_conn) orthogonal matrix whose first k columns are the
    criterion directions (after orthonormalisation), and whose remaining
    columns span the complement via SVD of the projected data.
    """
    n_conn = criterion_vecs.shape[0]
    k = criterion_vecs.shape[1]

    # Full QR decomposition — Q is (n_conn × n_conn) orthogonal
    Q, _ = np.linalg.qr(criterion_vecs, mode='complete')
    # Q[:, :k] ≈ criterion_vecs  (up to sign flips — that's fine for ENA)

    complement = Q[:, k:]          # (n_conn × n_conn-k)
    n_comp = n_conn - k

    if n_comp == 0:
        return Q

    # Project data into the complement subspace
    X_bar = centered @ complement  # (n_units × n_comp)

    if X_bar.shape[0] == 0 or X_bar.shape[1] == 0:
        return Q

    _, _, Vt = np.linalg.svd(X_bar, full_matrices=False)
    # Vt: (min(n_units, n_comp) × n_comp)
    r = Vt.shape[0]  # number of right singular vectors we got

    comp_cols = complement @ Vt.T  # (n_conn × r)

    if r < n_comp:
        # Pad with remaining columns of the QR complement, orthogonalised
        # against what we already have.
        used = np.hstack([Q[:, :k], comp_cols])  # (n_conn × k+r)
        # Collect unused complement columns
        remaining = complement @ _null_complement(Vt, n_comp)  # see below
        combined = np.hstack([used, remaining])
    else:
        combined = np.hstack([Q[:, :k], comp_cols])

    return combined


def _null_complement(Vt: np.ndarray, n_comp: int) -> np.ndarray:
    """
    Return an orthonormal basis for the null space of Vt (rows of Vt span
    a subspace; we want the complementary directions in R^n_comp).
    Vt: (r × n_comp) with r < n_comp.
    """
    # Use QR on Vt.T to get a full basis and take columns beyond r
    Q, _ = np.linalg.qr(Vt.T, mode='complete')
    return Q[:, Vt.shape[0]:]  # (n_comp × n_comp-r)


def _build_full_rotation(centered: np.ndarray, axes: list) -> np.ndarray:
    """
    Given a list of unit-vector axes (each shape (n_conn,)), build a full
    orthogonal rotation matrix using SVD for the complement subspace.
    """
    criterion_vecs = np.column_stack(axes)   # (n_conn × len(axes))
    return _orthogonal_svd(centered, criterion_vecs)


# ---------------------------------------------------------------------------
# Public rotation factories
# ---------------------------------------------------------------------------

def mean_rotation(group1, group2):
    """
    Mean rotation — axis 1 is the mean difference between two groups.

    Mirrors rENA's ``ena.rotate.by.mean``.

    Parameters
    ----------
    group1, group2 : array-like of bool (length n_units)
        Boolean masks identifying the two groups. Applied to the centred
        normalised networks in the order units appear in the fitted model.

    Returns
    -------
    callable : ``rotation_fn(centered) -> (n_connections × n_connections)``

    Example
    -------
    rotation = mean_rotation(
        meta["Condition"] == "FirstGame",
        meta["Condition"] == "SecondGame",
    )
    model = ENA().fit(..., rotation=rotation)
    """
    g1 = np.asarray(group1, dtype=bool)
    g2 = np.asarray(group2, dtype=bool)

    def rotation_fn(centered: np.ndarray) -> np.ndarray:
        if g1.sum() == 0 or g2.sum() == 0:
            raise ValueError("mean_rotation: each group must have at least one unit.")
        diff = centered[g1].mean(axis=0) - centered[g2].mean(axis=0)
        norm = np.linalg.norm(diff)
        if norm < 1e-10:
            raise ValueError(
                "mean_rotation: group means are identical; cannot define axis 1."
            )
        v1 = diff / norm
        return _build_full_rotation(centered, [v1])

    return rotation_fn


def generalized_rotation(x_var, y_var=None, select_2_groups=None):
    """
    Generalised Means Rotation (GMR).

    Mirrors rENA's ``ena.rotate.by.generalized``.

    Parameters
    ----------
    x_var : array-like (n_units,)
        Predictor for axis 1.  Numeric → OLS regression;
        string/categorical → first eigenvector of between-group scatter SB.
    y_var : array-like (n_units,) | None
        Predictor for axis 2.  If None, axis 2 comes from SVD of deflated data.
    select_2_groups : tuple(val1, val2) | None
        When x_var is categorical, use the mean-difference between exactly
        these two groups (instead of the first eigenvector of SB).

    Returns
    -------
    callable : ``rotation_fn(centered) -> (n_connections × n_connections)``

    Examples
    --------
    # Continuous predictor
    rotation = generalized_rotation(meta["CONFIDENCE.Change"].astype(float))

    # Categorical
    rotation = generalized_rotation(meta["Condition"])

    # Categorical, two explicit groups
    rotation = generalized_rotation(
        meta["Condition"],
        select_2_groups=("FirstGame", "SecondGame"),
    )
    """
    x_arr = np.asarray(x_var)
    y_arr = np.asarray(y_var) if y_var is not None else None

    def rotation_fn(centered: np.ndarray) -> np.ndarray:
        if (
            select_2_groups is not None
            and not (
                np.issubdtype(x_arr.dtype, np.floating)
                or np.issubdtype(x_arr.dtype, np.integer)
            )
        ):
            g1_val, g2_val = select_2_groups
            diff = (
                centered[x_arr == g1_val].mean(axis=0)
                - centered[x_arr == g2_val].mean(axis=0)
            )
            norm = np.linalg.norm(diff)
            v1 = diff / norm if norm > 1e-10 else diff
        else:
            v1 = _gmr(centered, x_arr)

        axes = [v1]

        if y_arr is not None:
            deflated = _deflate(centered, v1)
            v2 = _gmr(deflated, y_arr)
            axes.append(v2)

        return _build_full_rotation(centered, axes)

    return rotation_fn


def regression_rotation(x_var, y_var=None):
    """
    Regression rotation — ENA networks as dependent variable.

    Mirrors rENA's ``ena.rotate.by.hena.regression``.

    Parameters
    ----------
    x_var : array-like (n_units,)
        Predictor for axis 1 (numeric or 0/1-encoded categorical).
    y_var : array-like (n_units,) | None
        Predictor for axis 2.

    Returns
    -------
    callable : ``rotation_fn(centered) -> (n_connections × n_connections)``

    Example
    -------
    condition_binary = (meta["Condition"] == "FirstGame").astype(float)
    rotation = regression_rotation(condition_binary)
    model = ENA().fit(..., rotation=rotation)
    """
    x_arr = np.asarray(x_var, dtype=float)
    y_arr = np.asarray(y_var, dtype=float) if y_var is not None else None

    def rotation_fn(centered: np.ndarray) -> np.ndarray:
        v1 = _regression_axis(centered, x_arr)
        axes = [v1]

        if y_arr is not None:
            deflated = _deflate(centered, v1)
            v2 = _regression_axis(deflated, y_arr)
            axes.append(v2)

        return _build_full_rotation(centered, axes)

    return rotation_fn


def regression_rotation_2(x_var, y_var=None):
    """
    Regression rotation (reversed) — predictor as dependent variable.

    Mirrors rENA's ``ena.rotate.by.hena.regression_2``.

    Parameters
    ----------
    x_var : array-like (n_units,)
        Response variable for axis 1.
    y_var : array-like (n_units,) | None
        Response variable for axis 2.

    Returns
    -------
    callable : ``rotation_fn(centered) -> (n_connections × n_connections)``

    Example
    -------
    condition_binary = (meta["Condition"] == "FirstGame").astype(float)
    rotation = regression_rotation_2(condition_binary)
    """
    x_arr = np.asarray(x_var, dtype=float)
    y_arr = np.asarray(y_var, dtype=float) if y_var is not None else None

    def rotation_fn(centered: np.ndarray) -> np.ndarray:
        v1 = _regression_axis_2(centered, x_arr)
        axes = [v1]

        if y_arr is not None:
            deflated = _deflate(centered, v1)
            v2 = _regression_axis_2(deflated, y_arr)
            axes.append(v2)

        return _build_full_rotation(centered, axes)

    return rotation_fn
