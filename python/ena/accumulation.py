"""
ena.accumulation — Standalone ENA accumulation step.

Separates network accumulation from modeling so users can inspect, export,
or plug raw adjacency vectors into their own pipelines without committing
to a particular rotation or normalization approach.

    from ena import accumulate

    accum = accumulate(
        data,
        units         = "unit_key",
        conversations = "convo_key",
        codes         = CODES,
        window_size   = 4,
        window_forward= 0,
        binary        = True,
    )

    accum.connection_counts_      # (n_units × n_connections) raw adjacency matrix
    accum.row_connection_counts_  # (n_rows × n_connections) raw row adjacency matrix
    accum.unit_labels_            # unit labels in first-appearance order
    accum.codes_                  # code names
    accum.connection_names_       # e.g. ["Data & Technical Constraints", ...]
    accum.meta                    # DataFrame: one row per unit, unit-level columns
"""

from __future__ import annotations

from typing import List, Optional

import numpy as np
import pandas as pd

from qe import accumulation as _acc


class ENAAccumulation:
    """Result of :func:`accumulate`: raw adjacency vectors per unit.

    Attributes
    ----------
    connection_counts_ : np.ndarray, shape (n_units, n_connections)
        Raw (un-normalised) co-occurrence counts summed per unit.
        Corresponds to R's ``enadata$adjacency.vectors`` /
        ``set$connection.counts``.
    row_connection_counts_ : np.ndarray, shape (n_rows, n_connections)
        Raw (un-normalised) co-occurrence counts for each source row.
        Corresponds to R's ``set$model$row.connection.counts`` code columns.
    unit_labels_ : list[str]
        Unit labels in first-appearance order.
        Corresponds to R's ``set$model$unit.labels``.
    codes_ : list[str]
        Code names in model order.
    connection_names_ : list[str]
        Labels for each connection column, e.g. ``"Data & Technical Constraints"``.
        Order matches the column-major upper-triangle used by ``stanza_window``.
    meta : pd.DataFrame
        One row per unit (unit label as index).  Contains all non-code,
        non-unit-key columns from the original data, deduplicated per unit.
        Corresponds to R's ``set$meta.data``.
    source_call : dict | None
        The keyword arguments passed to :func:`accumulate` that produced this
        object (``data``, ``units``, ``conversations``, ``codes``,
        ``window_size``, ``window_forward``, ``binary``).  Corresponds to R's
        ``ENAAccumulation$`_function.call```; retained so the accumulation can
        be rebuilt at other window sizes (see :func:`ena.tune_window_size`).
        ``None`` when the object was constructed directly rather than via
        :func:`accumulate`.
    """

    def __init__(
        self,
        networks: np.ndarray,
        units: List[str],
        codes: List[str],
        connection_names: List[str],
        meta: pd.DataFrame,
        row_networks: Optional[np.ndarray] = None,
        source_call: Optional[dict] = None,
    ) -> None:
        self.connection_counts_ = networks
        self.row_connection_counts_ = (
            row_networks
            if row_networks is not None
            else np.zeros((0, networks.shape[1]), dtype=networks.dtype)
        )
        self.unit_labels_       = units
        self.codes_             = codes
        self.connection_names_  = connection_names
        self.meta               = meta
        self.source_call        = source_call

    def __repr__(self) -> str:
        return (
            f"<ENAAccumulation {len(self.unit_labels_)} units × "
            f"{len(self.connection_names_)} connections>"
        )


def accumulate(
    data: pd.DataFrame,
    units: str,
    conversations: str,
    codes: List[str],
    window_size: int = 4,
    window_forward: int = 0,
    binary: bool = True,
) -> ENAAccumulation:
    """Accumulate ENA co-occurrence networks without fitting a rotation.

    Runs the stanza-window accumulation step only, producing raw per-unit
    adjacency vectors.  The result can be passed directly to
    :meth:`ENA.fit` in place of a raw DataFrame, or used as-is for custom
    downstream analysis.

    Parameters
    ----------
    data : pd.DataFrame
    units : str
        Column whose values identify units of analysis.
    conversations : str
        Column whose values segment the data into conversations.
    codes : list[str]
        Code column names to include in the co-occurrence model.
    window_size : int
        Number of lines to look back (default 4).
    window_forward : int
        Number of lines to look forward (default 0).
    binary : bool
        If True (default), binarise co-occurrence counts.

    Returns
    -------
    ENAAccumulation

    Examples
    --------
    Basic accumulation::

        accum = accumulate(rs, "unit_key", "convo_key", CODES, window_size=4)
        print(accum.connection_counts_.shape)   # (48, 15)

    Inspect raw networks before modeling::

        import pandas as pd
        df = pd.DataFrame(accum.connection_counts_,
                          index=accum.unit_labels_,
                          columns=accum.connection_names_)

    Pass to ENA for modeling::

        model = ENA().fit(accum)
    """
    data = data.reset_index(drop=True)
    n_codes       = len(codes)
    n_connections = n_codes * (n_codes - 1) // 2

    unit_labels: List[str] = list(dict.fromkeys(data[units].tolist()))
    n_units = len(unit_labels)
    unit_index = {label: i for i, label in enumerate(unit_labels)}

    raw_networks = np.zeros((n_units, n_connections), dtype=np.float64)
    row_networks = np.zeros((len(data), n_connections), dtype=np.float64)

    for _, conv_df in data.groupby(conversations, sort=False):
        codes_mat = np.ascontiguousarray(
            conv_df[codes].to_numpy(dtype=np.float64)
        )
        co_occ = _acc.accumulate_stanza(codes_mat, window_size, window_forward, binary)
        for row_idx, unit_label in enumerate(conv_df[units].tolist()):
            source_idx = conv_df.index[row_idx]
            row_networks[source_idx] = co_occ[row_idx]
            raw_networks[unit_index[unit_label]] += co_occ[row_idx]

    # Column-major upper-triangle order matching stanza_window output.
    # Separator is " & " (with spaces) to match R's paste(..., collapse = " & ").
    connection_names = [
        f"{codes[i]} & {codes[j]}"
        for j in range(1, n_codes)
        for i in range(j)
    ]

    # Build unit-level metadata: one representative row per unit
    meta_cols = [c for c in data.columns if c != units and c not in codes]
    meta = (
        data[meta_cols + [units]]
        .drop_duplicates(subset=units)
        .set_index(units)
        .reindex(unit_labels)
    )

    return ENAAccumulation(
        networks=raw_networks,
        row_networks=row_networks,
        units=unit_labels,
        codes=list(codes),
        connection_names=connection_names,
        meta=meta,
        source_call={
            "data":           data,
            "units":          units,
            "conversations":  conversations,
            "codes":          list(codes),
            "window_size":    window_size,
            "window_forward": window_forward,
            "binary":         binary,
        },
    )
