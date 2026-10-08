"""
ena.libena — libena, the ENA C++ layer (rotations, node positions, CCD).

The C++ lives in this repository (``inst/include/libena``); ``ena._libena`` is
its nanobind extension.  These functions moved here from qe-lib (``import
qe``) in libqe's phase 4a split; signatures and results are unchanged.

The extension returns plain dicts so it can be loaded alongside other
products' extensions; the result classes below restore attribute access
(``result.centroids``) and the reprs qe-lib's classes had.

All matrix inputs/outputs are numpy float64 arrays.
"""
from __future__ import annotations

from typing import NamedTuple

import numpy as np

from . import _libena

__all__ = [
    "NodePositions",
    "RotationResult",
    "ena_correlation",
    "node_positions",
    "directed_node_positions",
    "directed_node_positions_combine_pairs",
    "ena_svd",
    "deflate",
    "orthogonal_svd",
    "complete_rotation",
    "means_rotation",
    "generalized_means_rotation",
    "ccd_window",
]


class NodePositions(NamedTuple):
    """Result of the node-position solvers.

    nodes     : ndarray (n_codes × n_dims)   — solved node coordinates
    centroids : ndarray (n_units × n_dims)   — unit centroid positions
    weights   : ndarray (n_units × n_codes)  — half-edge weight per node
    points    : ndarray (n_units × n_dims)   — input rotated points (echo)
    """
    nodes: np.ndarray
    centroids: np.ndarray
    weights: np.ndarray
    points: np.ndarray

    def __repr__(self) -> str:
        n, c = self.nodes.shape, self.centroids.shape
        return f"<NodePositions nodes={n[0]}x{n[1]} centroids={c[0]}x{c[1]}>"


class RotationResult(NamedTuple):
    """Result of the rotation routines.

    rotation     : ndarray (p × p)   — column j is rotation axis j
    eigenvalues  : ndarray (p,)      — sdev^2 from the underlying SVD
    column_names : list[str]         — labels for each column of rotation

    Eigenvalues match rENA's prcomp(...)$sdev^2 convention. For rotations
    that fix some named axes (means_rotation, complete_rotation), the
    eigenvalues for those leading columns are 0.
    """
    rotation: np.ndarray
    eigenvalues: np.ndarray
    column_names: list

    def __repr__(self) -> str:
        r = self.rotation.shape
        return (f"<RotationResult rotation={r[0]}x{r[1]} "
                f"labels=[{', '.join(self.column_names)}]>")


def _doc(fn):
    """Take the docstring from the extension function of the same name."""
    fn.__doc__ = getattr(_libena, fn.__name__).__doc__
    return fn


# ── correlation and node positions ───────────────────────────────────────────

@_doc
def ena_correlation(points, centroids, conf_level=0.95):
    return _libena.ena_correlation(points, centroids, conf_level)


@_doc
def node_positions(adj_mats, t, num_dims) -> NodePositions:
    return NodePositions(**_libena.node_positions(adj_mats, t, num_dims))


@_doc
def directed_node_positions(line_weights, points, num_dims) -> NodePositions:
    return NodePositions(**_libena.directed_node_positions(line_weights, points, num_dims))


@_doc
def directed_node_positions_combine_pairs(line_weights, points, num_dims) -> NodePositions:
    return NodePositions(**_libena.directed_node_positions_combine_pairs(
        line_weights, points, num_dims))


# ── rotation ─────────────────────────────────────────────────────────────────

@_doc
def ena_svd(points) -> RotationResult:
    return RotationResult(**_libena.ena_svd(points))


@_doc
def deflate(data, axis):
    return _libena.deflate(data, axis)


@_doc
def orthogonal_svd(data, weights, named_labels) -> RotationResult:
    return RotationResult(**_libena.orthogonal_svd(data, weights, named_labels))


@_doc
def complete_rotation(data, named_axes, named_labels) -> RotationResult:
    return RotationResult(**_libena.complete_rotation(data, named_axes, named_labels))


@_doc
def means_rotation(points, group_pairs) -> RotationResult:
    return RotationResult(**_libena.means_rotation(points, group_pairs))


@_doc
def generalized_means_rotation(V, x_model, x_target, x1_cols, x_categorical,
                               x_n_groups, x_subset, has_y, y_model, y_target,
                               y1_cols, y_categorical, y_n_groups,
                               n_lambda=50, k_folds=5, lasso_eps=0.01) -> RotationResult:
    return RotationResult(**_libena.generalized_means_rotation(
        V, x_model, x_target, x1_cols, x_categorical, x_n_groups, x_subset,
        has_y, y_model, y_target, y1_cols, y_categorical, y_n_groups,
        n_lambda, k_folds, lasso_eps))


# ── CCD ──────────────────────────────────────────────────────────────────────

def ccd_window(conversations, max_window=20, min_overlap=10) -> dict:
    """Cross-covariance decay (CCD) window-size estimation.

    Returns a dict with ``window_size``, ``peak_lag`` and the per-lag curves
    ``lag``, ``frob``, ``frob_sq_unbiased``, ``frob_unbiased_signed`` and
    ``total_weight`` (ndarrays of length ``max_window + 1``).  The public,
    data-frame level API is :func:`ena.ccd_window`.
    """
    return _libena.ccd_window(conversations, max_window, min_overlap)
