"""
pyena.ena — High-level ENA (Epistemic Network Analysis) pipeline.

Output field names mirror R's ena.set object (flat — no nested sub-objects).

Top-level (= R's set$...):
  connection_counts_       np.ndarray (n_units × n_connections) — raw accumulation
  line_weights_            np.ndarray (n_units × n_connections) — sphere-normed
  points_                  np.ndarray (n_units × dims)          — projected positions
  rotation_matrix_         np.ndarray (n_connections × dims)    — rotation vectors
  meta_data_               pd.DataFrame                         — unit metadata

model sub-fields (= R's set$model$...):
  centroids_               np.ndarray (n_units × dims)          — LWS centroids
  variance_                np.ndarray (dims,)                   — variance explained
  unit_labels_             list[str]
  points_for_projection_   np.ndarray (n_units × n_connections) — centered normed

rotation sub-fields (= R's set$rotation$...):
  rotation_nodes_          np.ndarray (n_codes × dims)          — code positions
  rotation_eigenvalues_    np.ndarray | None                    — singular values (SVD only)
  rotation_center_vec_     np.ndarray (n_connections,)          — centering vector
  rotation_adjacency_key_  list[list[str]]                      — [[codeI, codeJ], ...]
  codes_                   list[str]
  connection_names_        list[str]

Python-specific extras:
  full_rotation_           np.ndarray (n_connections × k) — full pre-truncation rotation
  weights_                 np.ndarray                     — LWS weights
  column_classes_          dict                           — R S3 class annotation per matrix
  accum_                   ENAAccumulation
"""

from __future__ import annotations

from typing import List, Optional, Union

import numpy as np
import pandas as pd

from pylibqe import normalization, modeling
from .accumulation import ENAAccumulation, accumulate as _accumulate
from .rotations import mean_rotation, generalized_rotation, regression_rotation, regression_rotation_2


# ── helpers ───────────────────────────────────────────────────────────────────

def _compute_variance(points: np.ndarray) -> np.ndarray:
    """
    Per-dimension variance explained (= R's model$variance).

    Matches R: diagonal(var(points)) / sum(diagonal(var(points)))
    R's var() uses sample variance (ddof=1).
    """
    if points.shape[0] < 2:
        return np.full(points.shape[1], 1.0 / points.shape[1])
    col_var = np.var(points, axis=0, ddof=1)
    total = col_var.sum()
    if total == 0:
        return np.full(points.shape[1], 1.0 / points.shape[1])
    return col_var / total


def _build_adjacency_key(codes: List[str]) -> List[List[str]]:
    """
    [[codeI, codeJ], ...] pairs for each connection (= R's rotation$adjacency.key).
    Column-major upper-triangle order, matching stanza_window output.
    """
    return [
        [codes[i], codes[j]]
        for j in range(1, len(codes))
        for i in range(j)
    ]


# ── ENA model ─────────────────────────────────────────────────────────────────

class ENA:
    """Standard Epistemic Network Analysis pipeline.

    Can be used in three equivalent styles:

    **One-liner** (accumulate + model in a single call)::

        model = ENA().fit(rs, "unit_key", "convo_key", CODES)

    **Constructor style** (data up front, options at fit time)::

        model = ENA(rs, "unit_key", "convo_key", CODES).fit()
        model = ENA(rs, "unit_key", "convo_key", CODES).fit(rotation=mean_rotation(g1, g2))

    **Chain style** (mirrors the R pipe)::

        model = ENA().accumulate(rs, "unit_key", "convo_key", CODES).fit()
        model = (ENA()
                   .accumulate(rs, "unit_key", "convo_key", CODES, window_size=8)
                   .fit(rotation=generalized_rotation(x_var)))

    Attributes set after fitting (= R's ena.set fields, flat)
    ---------------------------------------------------------
    connection_counts_      raw adjacency vectors (n_units × n_connections)
    line_weights_           sphere-normed adjacency vectors (= R set$line.weights)
    points_                 projected unit positions (= R set$points)
    rotation_matrix_        rotation matrix truncated to dims (= R set$rotation.matrix)
    meta_data_              unit metadata DataFrame (= R set$meta.data)
    centroids_              LWS centroid positions (= R model$centroids)
    variance_               variance explained per dimension (= R model$variance)
    unit_labels_            unit label strings (= R model$unit.labels)
    points_for_projection_  centered normed networks (= R model$points.for.projection)
    rotation_nodes_         code/node positions (= R rotation$nodes)
    rotation_eigenvalues_   singular values from SVD, or None for other rotations
    rotation_center_vec_    centering vector (= R rotation$center.vec)
    rotation_adjacency_key_ [[codeI, codeJ], ...] per connection
    codes_                  code name strings (= R rotation$codes)
    connection_names_       connection label strings
    full_rotation_          full rotation matrix before truncation (Python-specific)
    weights_                LWS weights (Python-specific)
    column_classes_         R S3 class annotation per matrix field (Python-specific)
    accum_                  ENAAccumulation used to build this model
    """

    def __init__(
        self,
        data: Optional[Union[pd.DataFrame, ENAAccumulation]] = None,
        units: Optional[str] = None,
        conversations: Optional[str] = None,
        codes: Optional[List[str]] = None,
        window_size: int = 4,
        window_forward: int = 0,
        binary: bool = True,
    ) -> None:
        """Optionally provide data up front; call .fit() to run the model."""
        if data is not None:
            self.accumulate(
                data, units, conversations, codes,
                window_size=window_size,
                window_forward=window_forward,
                binary=binary,
            )

    def accumulate(
        self,
        data: Union[pd.DataFrame, ENAAccumulation],
        units: Optional[str] = None,
        conversations: Optional[str] = None,
        codes: Optional[List[str]] = None,
        window_size: int = 4,
        window_forward: int = 0,
        binary: bool = True,
    ) -> "ENA":
        """Run the accumulation step and store the result.

        Returns ``self`` so you can chain directly into ``.fit()``.

        Parameters
        ----------
        data : pd.DataFrame | ENAAccumulation
            Raw data or a pre-built accumulation.
        units : str
            Column identifying units of analysis.
        conversations : str
            Column segmenting conversations.
        codes : list[str]
            Code column names.
        window_size : int
            Lines back for stanza window (default 4).
        window_forward : int
            Lines forward (default 0).
        binary : bool
            Binarise co-occurrences (default True).

        Examples
        --------
        Chain into fit::

            model = ENA().accumulate(rs, "unit_key", "convo_key", CODES).fit()
        """
        if isinstance(data, ENAAccumulation):
            self.accum_ = data
        else:
            if units is None or conversations is None or codes is None:
                raise ValueError(
                    "accumulate() requires units, conversations, and codes "
                    "when data is a DataFrame."
                )
            self.accum_ = _accumulate(
                data, units, conversations, codes,
                window_size=window_size,
                window_forward=window_forward,
                binary=binary,
            )
        return self

    def fit(
        self,
        data: Optional[Union[pd.DataFrame, ENAAccumulation]] = None,
        units: Optional[str] = None,
        conversations: Optional[str] = None,
        codes: Optional[List[str]] = None,
        window_size: int = 4,
        window_forward: int = 0,
        binary: bool = True,
        dims: int = 2,
        norm: str = "sphere",
        rotation=None,
    ) -> "ENA":
        """Fit an ENA model.

        Parameters
        ----------
        data : pd.DataFrame | ENAAccumulation | None
            * ``None``          — use the accumulation already stored by the
              constructor or a prior :meth:`accumulate` call.
            * ``ENAAccumulation`` — use this pre-built accumulation directly.
            * ``pd.DataFrame``  — accumulate and model in one step (``units``,
              ``conversations``, and ``codes`` are then required).
        dims : int
            Number of dimensions to retain (default 2).
        norm : str
            ``"sphere"`` (default) or ``"skip_sphere"``.
        rotation : None | np.ndarray | callable
            * ``None``        — default SVD rotation.
            * ``np.ndarray``  — pre-computed (n_connections × k) matrix.
            * callable        — factory from :func:`mean_rotation`,
              :func:`generalized_rotation`, :func:`regression_rotation`, or
              :func:`regression_rotation_2`.
        """
        if norm not in ("sphere", "skip_sphere"):
            raise ValueError(f"norm must be 'sphere' or 'skip_sphere', got {norm!r}")

        # ── accumulation ─────────────────────────────────────────────────────
        if data is None:
            if not hasattr(self, "accum_"):
                raise ValueError(
                    "No data provided. Either pass data to fit(), call "
                    ".accumulate() first, or pass data to ENA()."
                )
            accum = self.accum_
        else:
            self.accumulate(data, units, conversations, codes,
                            window_size=window_size,
                            window_forward=window_forward,
                            binary=binary)
            accum = self.accum_

        raw_networks = accum.connection_counts_

        # ── normalization ────────────────────────────────────────────────────
        if norm == "sphere":
            normed = normalization.sphere_norm(raw_networks)
        else:
            normed = normalization.skip_sphere_norm(raw_networks)

        # ── centering ────────────────────────────────────────────────────────
        # Center only non-zero rows (rENA center.align.to.origin=TRUE default).
        # center_vec = column means of non-zero rows (= R's rotation$center.vec).
        non_zero   = normed.sum(axis=1) != 0
        center_vec = normed[non_zero].mean(axis=0) if non_zero.any() else np.zeros(normed.shape[1])

        centered = np.zeros_like(normed)
        if non_zero.any():
            centered[non_zero] = modeling.center_data(
                np.ascontiguousarray(normed[non_zero])
            )

        # ── rotation ─────────────────────────────────────────────────────────
        rotation_eigenvalues = None
        if rotation is None:
            # Default: SVD rotation
            _, s, Vt = np.linalg.svd(centered, full_matrices=False)
            full_rot = Vt.T   # (n_connections × min(n_units, n_connections))
            rotation_eigenvalues = s
        elif isinstance(rotation, np.ndarray):
            full_rot = rotation
        elif callable(rotation):
            full_rot = rotation(centered)
        else:
            raise ValueError(
                f"rotation must be None, np.ndarray, or callable, got {type(rotation)}"
            )

        rotation_matrix = full_rot[:, :dims]
        t = centered @ rotation_matrix   # projected unit positions (= R's set$points)

        # ── node positions (LWS) ─────────────────────────────────────────────
        node_positions = modeling.lws_lsq_positions(
            np.ascontiguousarray(normed), np.ascontiguousarray(t), dims
        )

        # ── derived fields ────────────────────────────────────────────────────
        variance      = _compute_variance(t)
        adjacency_key = _build_adjacency_key(list(accum.codes_))

        # ── assign all output fields ──────────────────────────────────────────
        self.accum_                  = accum

        # top-level (= R's set$...)
        self.connection_counts_      = raw_networks          # set$connection.counts
        self.line_weights_           = normed                # set$line.weights
        self.points_                 = node_positions.points # set$points
        self.rotation_matrix_        = rotation_matrix       # set$rotation.matrix
        self.meta_data_              = accum.meta            # set$meta.data

        # model sub-fields (= R's set$model$...)
        self.centroids_              = node_positions.centroids  # model$centroids (LWS)
        self.variance_               = variance                  # model$variance
        self.unit_labels_            = accum.unit_labels_        # model$unit.labels
        self.points_for_projection_  = centered                  # model$points.for.projection

        # rotation sub-fields (= R's set$rotation$...)
        self.rotation_nodes_         = node_positions.nodes      # rotation$nodes
        self.rotation_eigenvalues_   = rotation_eigenvalues      # rotation$eigenvalues
        self.rotation_center_vec_    = center_vec                # rotation$center.vec
        self.rotation_adjacency_key_ = adjacency_key             # rotation$adjacency.key
        self.codes_                  = accum.codes_              # rotation$codes
        self.connection_names_       = accum.connection_names_

        # Python-specific extras
        self.full_rotation_          = full_rot               # full pre-truncation rotation
        self.weights_                = node_positions.weights # LWS weights

        # Column class annotations (mirrors R's S3 class tags per column)
        self.column_classes_         = {
            'connection_counts':          'ena.co.occurrence',
            'line_weights':               'ena.co.occurrence',
            'points':                     'ena.dimension',
            'points_for_projection':      'ena.co.occurrence',
            'rotation_matrix':            'ena.dimension',
            'rotation_nodes':             'ena.dimension',
        }

        return self
