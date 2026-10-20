"""
ena.ena — High-level ENA (Epistemic Network Analysis) pipeline.

Output field names mirror R's ena.set object (flat — no nested sub-objects).

Top-level (= R's set$...):
  connection_counts_       np.ndarray (n_units × n_connections) — raw accumulation
  row_connection_counts_   np.ndarray (n_rows × n_connections)  — row-level raw accumulation
  line_weights_            np.ndarray (n_units × n_connections) — sphere-normed
  points_                  np.ndarray (n_units × dims)          — projected positions
  rotation_matrix_         np.ndarray (n_connections × dims)    — rotation vectors
  meta_data_               pd.DataFrame                         — unit metadata

model sub-fields (= R's set$model$...):
  centroids_               np.ndarray (n_units × dims)          — LWS centroids
  variance_                np.ndarray (n_rotation_dims,)        — variance explained, every dimension
  unit_labels_             list[str]
  points_for_projection_   np.ndarray (n_units × n_connections) — centered normed

rotation sub-fields (= R's set$rotation$...):
  rotation_nodes_          np.ndarray (n_codes × dims)          — code positions
  rotation_eigenvalues_    np.ndarray | None                    — SVD eigenvalues, sdev^2 (= R rotation$eigenvalues)
  rotation_center_vec_     np.ndarray (n_connections,)          — centering vector
  rotation_adjacency_key_  list[list[str]]                      — [[codeI, codeJ], ...]
  codes_                   list[str]
  connection_names_        list[str]

Python-specific extras:
  full_rotation_           np.ndarray (n_connections × k) — full pre-truncation rotation
  weights_                 np.ndarray                     — LWS weights
  column_classes_          dict                           — R S3 class annotation per matrix
  accum_                   ENAAccumulation (or qe-tma's TMAAccumulation)
  ordered_                 bool — directed (ONA) networks, from the accumulation
  self_weight_             float — a self-connection's weight in its node's weight
"""

from __future__ import annotations

import copy
from typing import List, Optional, Union

import numpy as np
import pandas as pd

from qe import normalization, modeling

from . import libena
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


def _is_accumulation(data) -> bool:
    """An ENAAccumulation, or any accumulation with its fields -- e.g. qe-tma's
    TMAAccumulation (``tma.accumulate()``), which qe-ena models as rENA
    models tma's accumulation in R."""
    return isinstance(data, ENAAccumulation) or (
        hasattr(data, "connection_counts_") and hasattr(data, "codes_")
    )


def _key_indices(key: List[List[str]], codes: List[str]):
    """0-based (from, to) code indices per column of an adjacency key."""
    index = {c: i for i, c in enumerate(codes)}
    return [index[a] for a, _ in key], [index[b] for _, b in key]


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
    row_connection_counts_  row-level raw adjacency vectors (= R model$row.connection.counts)
    line_weights_           sphere-normed adjacency vectors (= R set$line.weights)
    points_                 projected unit positions (= R set$points)
    rotation_matrix_        rotation matrix truncated to dims (= R set$rotation.matrix)
    meta_data_              unit metadata DataFrame (= R set$meta.data)
    centroids_              LWS centroid positions (= R model$centroids)
    variance_               share of the total variance per rotated dimension, over
                            every dimension of the rotation (= R model$variance; the
                            first ``dims`` entries are the plotted dimensions)
    unit_labels_            unit label strings (= R model$unit.labels)
    points_for_projection_  centered normed networks (= R model$points.for.projection)
    rotation_nodes_         code/node positions (= R rotation$nodes)
    rotation_eigenvalues_   SVD eigenvalues as sdev^2 (= R), or None for other rotations
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
        if _is_accumulation(data):
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
        self_weight: float = 2.0,
    ) -> "ENA":
        """Fit an ENA model.

        Parameters
        ----------
        data : pd.DataFrame | ENAAccumulation | TMAAccumulation | None
            * ``None``          — use the accumulation already stored by the
              constructor or a prior :meth:`accumulate` call.
            * ``ENAAccumulation`` — use this pre-built accumulation directly.
            * qe-tma's ``TMAAccumulation`` (``tma.accumulate()``) — model it
              (= rENA's ``model()`` on tma's accumulation): ordered networks
              get ONA's directed node positions; unordered ones with
              self-connection columns (A & A, A & B, B & B, ...) are placed by
              their adjacency key.
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
        self_weight : float
            Weight of a self-connection (an ordered network's diagonal, or an
            unordered network's A & A columns) in its code's node weight:
            2 (default, = R's ``self_weight``) = row + column sum; 1 = once.
            Has no effect on networks without self-connections.
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
            normed = normalization.normalize_networks(raw_networks)
        else:
            normed = normalization.scale_networks(raw_networks)

        # ── centering ────────────────────────────────────────────────────────
        # Center only non-zero rows (rENA center.align.to.origin=TRUE default).
        # center_vec = column means of non-zero rows (= R's rotation$center.vec).
        non_zero   = normed.sum(axis=1) != 0
        center_vec = normed[non_zero].mean(axis=0) if non_zero.any() else np.zeros(normed.shape[1])

        centered = np.zeros_like(normed)
        if non_zero.any():
            centered[non_zero] = modeling.center_points(
                np.ascontiguousarray(normed[non_zero])
            )

        # ── rotation ─────────────────────────────────────────────────────────
        rotation_eigenvalues = None
        if rotation is None:
            # Default: SVD rotation (libena ena_svd = R's ena.svd: prcomp on the
            # centered points, eigenvalues as sdev^2). Keep min(n_units,
            # n_connections) axes, as prcomp returns.
            svd = libena.ena_svd(np.ascontiguousarray(centered))
            k = min(centered.shape)
            full_rot = svd.rotation[:, :k]   # (n_connections × min(n_units, n_connections))
            rotation_eigenvalues = svd.eigenvalues[:k]
        elif isinstance(rotation, np.ndarray):
            full_rot = rotation
        elif callable(rotation):
            full_rot = rotation(centered)
        else:
            raise ValueError(
                f"rotation must be None, np.ndarray, or callable, got {type(rotation)}"
            )

        if not isinstance(dims, (int, np.integer)) or isinstance(dims, bool) or dims < 1:
            raise ValueError(f"dims must be a positive integer, got {dims!r}")
        if dims > full_rot.shape[1]:
            raise ValueError(
                f"dims={dims} but the rotation has only {full_rot.shape[1]} dimensions "
                f"(at most min(units, connections))"
            )
        rotation_matrix = full_rot[:, :dims]
        t = centered @ rotation_matrix   # projected unit positions (= R's set$points)

        # ── node positions (LWS) ─────────────────────────────────────────────
        # Ordered: ONA's directed weighting. Unordered: the standard
        # choose(n, 2) layout keeps the undirected solver; any other layout
        # (self-connection columns) is placed by its adjacency key (libena's
        # key-driven solver, = the undirected one for choose(n, 2)).
        codes    = list(accum.codes_)
        ordered  = bool(getattr(accum, "ordered_", False))
        key      = getattr(accum, "adjacency_key_", None)
        key      = [list(k) for k in key] if key is not None else _build_adjacency_key(codes)
        by_key   = not ordered and key != _build_adjacency_key(codes)
        lw_c, t_c = np.ascontiguousarray(normed), np.ascontiguousarray(t)
        if ordered:
            node_positions = libena.directed_node_positions(lw_c, t_c, dims, self_weight=self_weight)
        elif by_key:
            key_from, key_to = _key_indices(key, codes)
            node_positions = libena.node_positions_by_key(lw_c, t_c, dims, key_from, key_to,
                                                          len(codes), self_weight=self_weight)
        else:
            node_positions = libena.node_positions(lw_c, t_c, dims)

        # ── derived fields ────────────────────────────────────────────────────
        # Share of the total variance per rotated dimension, over every
        # dimension of the rotation, as R's model$variance (not renormalised
        # over the `dims` retained ones).
        variance      = _compute_variance(centered @ full_rot)
        adjacency_key = key

        # ── assign all output fields ──────────────────────────────────────────
        self.accum_                  = accum

        # top-level (= R's set$...)
        self.connection_counts_      = raw_networks          # set$connection.counts
        self.row_connection_counts_  = getattr(accum, "row_connection_counts_", None)
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
        self.ordered_                = ordered                # directed (ONA) networks
        self.self_weight_            = float(self_weight)     # rotation$self.weight
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

    def move_nodes_to_unit_circle(self, dims=(0, 1), mode: str = "equal") -> "ENA":
        """Move the nodes onto a circle in the plane of two dimensions.

        A post-fit display transform (libena's ``move_nodes_to_unit_circle``,
        shared with rENA, rena-wasm and ENA.jl): the nodes move onto a circle
        with the radius of the longest node in that plane, and the centroids
        are recomputed for the moved nodes. Nothing is refit; the points are
        unchanged. Nodes of length zero in the plane, and the nodes' other
        dimensions, stay where they are.

        Parameters
        ----------
        dims : (int, int)
            0-based dimensions (columns of ``rotation_nodes_``) spanning the
            plane, x then y. Default: the first two.
        mode : str
            ``"equal"`` (default) — the nodes keep their order around the
            origin and are spaced 2π/n apart, the longest one fixed (= R's
            ``move_nodes_to_unit_circle_with_equal_space()``).
            ``"radial"`` — each node moves out along its own ray (= R's
            ``move_nodes_to_unit_circle()``).

        Returns
        -------
        ENA
            A copy of this model with ``rotation_nodes_`` and ``centroids_``
            replaced. This model is unchanged, so the move can be redone from
            its fitted nodes, e.g. for another pair of dimensions.
        """
        if not hasattr(self, "rotation_nodes_"):
            raise ValueError("fit() the model before moving its nodes")
        dim_x, dim_y = dims
        lw    = np.ascontiguousarray(self.line_weights_, dtype=np.float64)
        nodes = np.ascontiguousarray(self.rotation_nodes_, dtype=np.float64)
        ordered     = getattr(self, "ordered_", False)
        self_weight = getattr(self, "self_weight_", 2.0)
        if not ordered and self.rotation_adjacency_key_ != _build_adjacency_key(list(self.codes_)):
            key_from, key_to = _key_indices(self.rotation_adjacency_key_, list(self.codes_))
            moved = libena.move_nodes_to_unit_circle_by_key(
                lw, nodes, int(dim_x), int(dim_y), mode, key_from, key_to, self_weight)
        else:
            moved = libena.move_nodes_to_unit_circle(
                lw, nodes, int(dim_x), int(dim_y), mode, ordered, self_weight)
        out = copy.copy(self)
        out.rotation_nodes_ = moved.nodes
        out.centroids_      = moved.centroids
        return out

    def conf_ints(self, points: Optional[np.ndarray] = None,
                  conf_level: float = 0.95) -> np.ndarray:
        """Per-dimension t-based confidence intervals around the column means.

        Parameters
        ----------
        points : np.ndarray | None
            Units × dims matrix. Defaults to ``self.points_``.
        conf_level : float
            Confidence level (default 0.95).

        Returns
        -------
        np.ndarray, shape (dims, 3)
            Columns: mean, lower CI, upper CI — one row per dimension.
        """
        pts = self.points_ if points is None else points
        return modeling.mean_ci(np.ascontiguousarray(pts, dtype=np.float64),
                                conf_level)

    def outlier_ints(self, points: Optional[np.ndarray] = None,
                     iqr_factor: float = 1.5) -> np.ndarray:
        """Per-dimension Tukey-fence outlier intervals (Q1-k*IQR, Q3+k*IQR).

        Parameters
        ----------
        points : np.ndarray | None
            Units × dims matrix. Defaults to ``self.points_``.
        iqr_factor : float
            IQR multiplier k (default 1.5).

        Returns
        -------
        np.ndarray, shape (dims, 2)
            Columns: lower fence, upper fence — one row per dimension.
        """
        pts = self.points_ if points is None else points
        return modeling.outlier_ci(np.ascontiguousarray(pts, dtype=np.float64),
                                   iqr_factor)

    def compare_groups(self, g1_mask: np.ndarray,
                       g2_mask: np.ndarray) -> "modeling.GroupStatsResult":
        """Per-dimension parametric and non-parametric two-group statistics.

        Parameters
        ----------
        g1_mask : np.ndarray of bool
            Boolean index selecting group 1 rows from ``self.points_``.
        g2_mask : np.ndarray of bool
            Boolean index selecting group 2 rows from ``self.points_``.

        Returns
        -------
        GroupStatsResult
            Fields: n1, n2, t, df, pvalue_t, cohens_d, means, sds,
            U, pvalue_u, effect_r, medians — each length dims.
        """
        g1 = np.ascontiguousarray(self.points_[g1_mask], dtype=np.float64)
        g2 = np.ascontiguousarray(self.points_[g2_mask], dtype=np.float64)
        return modeling.group_stats(g1, g2)
