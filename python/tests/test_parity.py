"""
test_parity.py — Cross-binding parity tests for pyena.

These tests replicate assertions from the R testthat suite using the same
shared data files (inst/extdata/rs.data.csv) and the same small inline
datasets used in the R tests.  Every test cites its R source.

R sources:
  - tests/testthat/test.ena.make.set.R
  - tests/testthat/test-rotation_matrix.R
  - tests/testthat/test-zero-networks.R
  - tests/testthat/test.ena.accumulations.R

Field names mirror R's ena.set structure (see pyena/ena.py module docstring).
"""

from __future__ import annotations

import pathlib

import numpy as np
import pandas as pd
import pytest

from pyena import ENA, accumulate

# ── paths ─────────────────────────────────────────────────────────────────────

HERE    = pathlib.Path(__file__).parent
EXTDATA = HERE / "../../inst/extdata"

RS_CSV  = EXTDATA / "rs.data.csv"

# ── RS.data codes ─────────────────────────────────────────────────────────────
# Column names in the CSV use spaces (R's read.csv converts them to dots).

RS_CODES = [
    "Data",
    "Technical Constraints",
    "Performance Parameters",
    "Client and Consultant Requests",
    "Design Reasoning",
    "Collaboration",
]

# ── shared fixtures ───────────────────────────────────────────────────────────

@pytest.fixture(scope="module")
def rs():
    """RS.data loaded from CSV, with composite unit and conversation keys."""
    df = pd.read_csv(RS_CSV)
    # R: units.by = c("UserName", "Condition")
    df["unit_key"] = df["UserName"] + "::" + df["Condition"]
    # R: conversations.by = c("ActivityNumber", "GroupName")
    df["convo_key"] = df["ActivityNumber"].astype(str) + "::" + df["GroupName"]
    return df


@pytest.fixture(scope="module")
def rs_model(rs):
    """Full ENA model on RS.data — equivalent to R's ena.make.set(accum)."""
    return ENA().fit(rs, "unit_key", "convo_key", RS_CODES)


@pytest.fixture(scope="module")
def rs_accum(rs):
    return accumulate(rs, "unit_key", "convo_key", RS_CODES)


# ── RS.data structural tests ──────────────────────────────────────────────────
# Source: test.ena.make.set.R — "Simple data.frame to accumulate and make set"
#   expect_equal(length(set$rotation$codes), 6)
#   expect_equal(dim(as.matrix(set$points)), c(48, choose(6,2)))
#   expect_equal(length(set$model$unit.labels), 48)

class TestRSDataStructural:
    """Mirror of test.ena.make.set.R structural assertions."""

    def test_6_codes(self, rs_model):
        assert len(rs_model.codes_) == 6

    def test_15_connections_choose_6_2(self, rs_model):
        # choose(6, 2) = 15
        assert rs_model.connection_counts_.shape[1] == 15

    def test_48_units(self, rs_model):
        # 24 unique users × 2 conditions
        assert rs_model.connection_counts_.shape[0] == 48

    # R: expect_equal(length(set$model$unit.labels), 48)
    def test_48_unit_labels(self, rs_model):
        assert len(rs_model.unit_labels_) == 48

    # R: set$model$centroids — LWS centroids, shape 48 × 2
    def test_centroids_shape_48x2(self, rs_model):
        assert rs_model.centroids_.shape == (48, 2)

    # R: set$rotation$nodes — code node positions, shape 6 × 2
    def test_rotation_nodes_shape_6x2(self, rs_model):
        assert rs_model.rotation_nodes_.shape == (6, 2)

    # R: set$line.weights — normed networks, shape 48 × 15
    def test_line_weights_shape_48x15(self, rs_model):
        assert rs_model.line_weights_.shape == (48, 15)

    # R: set$connection.counts — raw networks, shape 48 × 15
    def test_connection_counts_shape_48x15(self, rs_model):
        assert rs_model.connection_counts_.shape == (48, 15)

    # R: set$rotation.matrix — rotation matrix, shape 15 × 2
    def test_rotation_matrix_shape_15x2(self, rs_model):
        assert rs_model.rotation_matrix_.shape == (15, 2)

    # R: model$variance — variance explained (sums to 1)
    def test_variance_sums_to_1(self, rs_model):
        assert np.isclose(rs_model.variance_.sum(), 1.0, atol=1e-10)

    # R: rotation$center.vec — centering vector, length 15
    def test_rotation_center_vec_length(self, rs_model):
        assert len(rs_model.rotation_center_vec_) == 15

    # Source: test.ena.make.set.R — rotation matrix column name
    #   expect_equal("SVD1", colnames(set.svd$rotation.matrix)[2])
    # Python doesn't yet store column names — tracked in column_classes_ instead.
    def test_rotation_matrix_shape(self, rs_model):
        # rotation_matrix_ is (n_connections × dims) = (15 × 2)
        assert rs_model.rotation_matrix_.shape == (15, 2)


# ── Connection name format ────────────────────────────────────────────────────
# Source: test-rotation_matrix.R
#   as.character(set$rotation.matrix[[1]]) == colnames(as.matrix(set$connection.counts))
# R uses " & " as the separator between code names.

class TestConnectionNames:
    """Connection name format — must use ' & ' separator to match R."""

    def test_rs_data_connection_names_use_spaced_ampersand(self, rs_accum):
        # R: "Data & Technical.Constraints" etc.
        assert all(" & " in n for n in rs_accum.connection_names_), (
            "Connection names use '&' without spaces; expected ' & ' to match R."
        )

    def test_rs_data_first_connection_name(self, rs_accum):
        # R: colnames(set$connection.counts)[1] == "Data & Technical Constraints"
        assert rs_accum.connection_names_[0] == "Data & Technical Constraints"

    def test_3_code_connection_names(self):
        df = pd.DataFrame({
            "unit":  ["A", "A", "B", "B"],
            "convo": ["c1", "c1", "c1", "c1"],
            "c1": [1., 1., 0., 1.],
            "c2": [1., 0., 1., 1.],
            "c3": [0., 1., 1., 0.],
        })
        accum = accumulate(df, "unit", "convo", ["c1", "c2", "c3"])
        # R: "c1 & c2", "c1 & c3", "c2 & c3"
        assert accum.connection_names_ == ["c1 & c2", "c1 & c3", "c2 & c3"]


# ── Accumulation — known numeric values from R ────────────────────────────────
# Source: test.ena.accumulations.R — "Test forward windows"
#
#   df_accum_inf_forward: window.size.back=0, window.size.forward=Inf
#     expect_equal(as.numeric(as.matrix(
#       df_accum_inf_forward$connection.counts)[1, ]), c(4, 6, 4))
#
#   df_accum_forward: window.size.back=5, window.size.forward=5
#     expect_equal(as.numeric(as.matrix(
#       df_accum_forward$connection.counts)[1, ]), c(5, 6, 6))

# Inline dataset from test.ena.accumulations.R
_NAMES = ["J", "Z"] * 6
_DAYS  = [1]*6 + [2]*6
_C1    = [1,1,1,1,1,0, 0,1,1,0,0,1]
_C2    = [1,1,1,0,0,1, 0,1,0,1,0,0]
_C3    = [0,0,1,0,1,0, 1,0,0,0,1,0]

DF_FWD = pd.DataFrame({
    "Name": _NAMES, "Day": _DAYS,
    "c1": _C1, "c2": _C2, "c3": _C3,
})

CODES_3 = ["c1", "c2", "c3"]


class TestAccumulationKnownValues:
    """
    Numeric parity with R's test.ena.accumulations.R 'Test forward windows'.
    Values are R ground-truth; if these fail the accumulation diverges from R.
    """

    def test_forward_inf_back_0_unit_J(self):
        """
        R: window.size.back=0, window.size.forward=Inf
           connection.counts[1,] == c(4, 6, 4)   # unit J
        """
        accum = accumulate(DF_FWD, "Name", "Day", CODES_3,
                           window_size=0, window_forward=9999)
        j_idx = accum.unit_labels_.index("J")
        assert list(accum.connection_counts_[j_idx].astype(int)) == [4, 6, 4], (
            f"Got {list(accum.connection_counts_[j_idx])} — expected [4, 6, 4] (from R)"
        )

    def test_bidirectional_5_5_unit_J(self):
        """
        R: window.size.back=5, window.size.forward=5
           connection.counts[1,] == c(5, 6, 6)   # unit J
        """
        accum = accumulate(DF_FWD, "Name", "Day", CODES_3,
                           window_size=5, window_forward=5)
        j_idx = accum.unit_labels_.index("J")
        assert list(accum.connection_counts_[j_idx].astype(int)) == [5, 6, 6], (
            f"Got {list(accum.connection_counts_[j_idx])} — expected [5, 6, 6] (from R)"
        )

    def test_window_1_differs_from_window_inf(self):
        """window=1 vs window=9999 must give different unit-level accumulations."""
        r1   = accumulate(DF_FWD, "Name", "Day", CODES_3, window_size=1)
        rInf = accumulate(DF_FWD, "Name", "Day", CODES_3, window_size=9999)
        assert not np.array_equal(r1.connection_counts_, rInf.connection_counts_)

    def test_unit_J_is_first(self):
        accum = accumulate(DF_FWD, "Name", "Day", CODES_3)
        assert accum.unit_labels_[0] == "J"


# ── Zero-network behavioral invariant ─────────────────────────────────────────
# Source: test-zero-networks.R
#   set_T = ena.make.set(enadata=accum, center.align.to.origin=TRUE)
#   expect_equal(sum(as.matrix(set_T$points[zero_units_rows])), 0)
#   expect_equal(sum(colMeans(as.matrix(set_T$model$centroids[zero_units_rows]))), 0)

_ZERO_DF = pd.DataFrame({
    "unit":  ["Active", "Active", "Zero", "Zero"],
    "convo": ["c1",     "c1",     "c2",   "c2"  ],
    "x":     [1.,       1.,       1.,     1.    ],
    "y":     [1.,       0.,       0.,     0.    ],
    "z":     [0.,       1.,       0.,     0.    ],
})

CODES_XYZ = ["x", "y", "z"]


class TestZeroNetworkInvariant:
    """Mirror of test-zero-networks.R zero-network behavioral invariants."""

    def test_zero_unit_raw_accumulation_is_zero(self):
        """Zero unit never sees a code pair in any stanza → accumulation = 0."""
        accum = accumulate(_ZERO_DF, "unit", "convo", CODES_XYZ)
        z_idx = accum.unit_labels_.index("Zero")
        assert np.all(accum.connection_counts_[z_idx] == 0)

    def test_zero_unit_normed_network_is_zero(self):
        """Sphere-norm of a zero vector is zero."""
        model = ENA().fit(_ZERO_DF, "unit", "convo", CODES_XYZ)
        z_idx = model.unit_labels_.index("Zero")
        assert np.all(model.line_weights_[z_idx] == 0)

    # R: expect_equal(sum(as.matrix(set_T$points[zero_units_rows])), 0)
    def test_zero_unit_projects_to_origin(self):
        """R invariant: zero-network unit projects to origin (set$points)."""
        model = ENA().fit(_ZERO_DF, "unit", "convo", CODES_XYZ)
        z_idx = model.unit_labels_.index("Zero")
        np.testing.assert_allclose(
            model.points_[z_idx], np.zeros(2), atol=1e-10,
            err_msg="Zero-network unit should project to origin (R invariant)"
        )

    # R: expect_equal(sum(colMeans(as.matrix(set_T$model$centroids[zero_units_rows]))), 0)
    def test_zero_unit_lws_centroid_is_zero(self):
        """R invariant: model$centroids for zero-network units is zero."""
        model = ENA().fit(_ZERO_DF, "unit", "convo", CODES_XYZ)
        z_idx = model.unit_labels_.index("Zero")
        np.testing.assert_allclose(
            model.centroids_[z_idx], np.zeros(2), atol=1e-10,
            err_msg="Zero-network unit LWS centroid should be zero (R invariant)"
        )

    # R: expect_equal(sum(colMeans(as.matrix(set_T$model$centroids))), 0)
    def test_mean_centroid_is_zero(self):
        """R: sum(colMeans(set_T$model$centroids)) == 0"""
        model = ENA().fit(_ZERO_DF, "unit", "convo", CODES_XYZ)
        np.testing.assert_allclose(
            model.centroids_.mean(axis=0), np.zeros(2), atol=1e-10,
            err_msg="Mean centroid should be zero when aligned to origin (R invariant)"
        )

    def test_active_unit_has_nonzero_normed_network(self):
        """
        Active unit has code co-occurrences → line_weights_ row is non-zero.
        Note: with only 1 non-zero unit the LWS system is singular, so
        model.points_ may be [0,0].  The meaningful invariant is line_weights_.
        """
        model = ENA().fit(_ZERO_DF, "unit", "convo", CODES_XYZ)
        a_idx = model.unit_labels_.index("Active")
        assert not np.allclose(model.line_weights_[a_idx], 0, atol=1e-10)
