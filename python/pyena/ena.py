"""
pyena.ena — High-level ENA (Epistemic Network Analysis) pipeline.
"""

from __future__ import annotations

from typing import List, Optional, Union

import numpy as np
import pandas as pd

from pylibqe import normalization, modeling
from .accumulation import ENAAccumulation, accumulate as _accumulate
from .rotations import mean_rotation, generalized_rotation, regression_rotation, regression_rotation_2


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

    Attributes set after fitting
    ----------------------------
    units_ : list[str]
    codes_ : list[str]
    connection_names_ : list[str]  — "codeA&codeB" labels in upper-tri order
    networks_ : np.ndarray (n_units × n_connections)  — raw adjacency vectors
    normed_networks_ : np.ndarray  — normalized adjacency vectors
    positions_ : np.ndarray (n_codes × dims)  — node positions
    centroids_ : np.ndarray (n_units × dims)  — unit centroids
    weights_ : np.ndarray
    points_ : np.ndarray (n_units × dims)
    accum_ : ENAAccumulation  — the accumulation used to build this model
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
        """Optionally provide data up front; call .fit() to run the model.

        All parameters are the same as :meth:`accumulate` / :meth:`fit`.
        Passing them here is equivalent to passing them to :meth:`accumulate`.
        """
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

        Accumulate once, model twice with different rotations::

            ena = ENA().accumulate(rs, "unit_key", "convo_key", CODES)
            model_svd = ena.fit()
            model_mr  = ENA().accumulate(rs, "unit_key", "convo_key", CODES).fit(
                            rotation=mean_rotation(g1, g2))
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
            # Use whatever was stored by __init__ or .accumulate()
            if not hasattr(self, "accum_"):
                raise ValueError(
                    "No data provided. Either pass data to fit(), call "
                    ".accumulate() first, or pass data to ENA()."
                )
            accum = self.accum_
        else:
            # Delegate to .accumulate() which handles both DataFrame and ENAAccumulation
            self.accumulate(data, units, conversations, codes,
                            window_size=window_size,
                            window_forward=window_forward,
                            binary=binary)
            accum = self.accum_

        raw_networks = accum.networks_

        # ── normalization ────────────────────────────────────────────────────
        if norm == "sphere":
            normed = normalization.sphere_norm(raw_networks)
        else:
            normed = normalization.skip_sphere_norm(raw_networks)

        # ── centering ────────────────────────────────────────────────────────
        # Center only non-zero rows (rENA center.align.to.origin=TRUE default)
        centered = np.zeros_like(normed)
        non_zero = normed.sum(axis=1) != 0
        if non_zero.any():
            centered[non_zero] = modeling.center_data(
                np.ascontiguousarray(normed[non_zero])
            )

        # ── rotation ─────────────────────────────────────────────────────────
        if rotation is None:
            _, _, Vt = np.linalg.svd(centered, full_matrices=False)
            full_rot = Vt.T  # (n_connections × min(n_units, n_connections))
        elif isinstance(rotation, np.ndarray):
            full_rot = rotation
        elif callable(rotation):
            full_rot = rotation(centered)
        else:
            raise ValueError(
                f"rotation must be None, np.ndarray, or callable, got {type(rotation)}"
            )

        rotation_matrix = full_rot[:, :dims]
        t = centered @ rotation_matrix

        node_positions = modeling.lws_lsq_positions(
            np.ascontiguousarray(normed), np.ascontiguousarray(t), dims
        )

        self.accum_            = accum
        self.rotation_         = rotation_matrix   # (n_connections × dims)
        self.full_rotation_    = full_rot           # (n_connections × k)
        self.units_            = accum.units_
        self.codes_            = accum.codes_
        self.connection_names_ = accum.connection_names_
        self.networks_         = raw_networks
        self.normed_networks_  = normed
        self.positions_        = node_positions.nodes
        self.centroids_        = node_positions.centroids
        self.weights_          = node_positions.weights
        self.points_           = node_positions.points

        return self
