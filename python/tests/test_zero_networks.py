"""Units whose network is all zeros follow ena.make.set(center.align.to.origin
= TRUE), the rule of rENA's model(exclude_zero_networks = TRUE) and of ONA
0.1.1: such a unit stays at the origin, is left out of the centering mean and
the node fit, and has a zero centroid; for unordered models the nodes and
centroids are shifted so the fitted units' mean centroid is at the origin.

fixtures/zero-networks.json holds rENA's model() (SVD rotation) on RS.data
accumulated by UserName, Condition and GroupName at window 4 -- two empty
units in the unordered set, one in the ordered set -- from
fixtures/zero-networks.R. The accumulations are rebuilt from R's connection
counts, so no qe-tma is needed.
"""
import json
from pathlib import Path
from types import SimpleNamespace

import numpy as np
import pandas as pd
import pytest

from ena import ENA

HERE = Path(__file__).parent
FIXTURE = json.loads((HERE / "fixtures/zero-networks.json").read_text())
CODES = FIXTURE["codes"]
DIMS = 6


def as_accumulation(case, ordered, keep=None):
    key = [list(k) for k in case["adjacency_key"]]
    counts = np.array(case["connection_counts"], dtype=float)
    units = list(case["units"])
    if keep is not None:
        counts, units = counts[keep], [u for u, k in zip(units, keep) if k]
    return SimpleNamespace(
        connection_counts_=counts,
        unit_labels_=units,
        codes_=list(CODES),
        connection_names_=[f"{a} & {b}" for a, b in key],
        adjacency_key_=key,
        meta=pd.DataFrame(index=units),
        ordered_=ordered,
    )


def empty_rows(case):
    e = np.zeros(len(case["units"]), dtype=bool)
    e[np.array(case["empty"]) - 1] = True
    return e


def signs(got, want):
    """SVD axes are defined up to sign: the sign aligning each of got's columns to want's."""
    return np.array([1.0 if (got[:, d] * want[:, d]).sum() >= 0 else -1.0 for d in range(want.shape[1])])


def assert_matches_r(model, case):
    points, nodes, centroids = (np.array(case[k]) for k in ("points", "nodes", "centroids"))
    np.testing.assert_allclose(model.line_weights_, case["line_weights"], atol=1e-12)
    s = signs(model.points_, points)
    np.testing.assert_allclose(model.points_ * s, points, atol=1e-10)
    np.testing.assert_allclose(model.rotation_nodes_ * s, nodes, atol=1e-10)
    np.testing.assert_allclose(model.centroids_ * s, centroids, atol=1e-10)
    np.testing.assert_allclose(model.rotation_eigenvalues_[:DIMS], case["eigenvalues"], atol=1e-10)
    np.testing.assert_allclose(model.variance_[:DIMS], case["variance"], atol=1e-10)


@pytest.mark.parametrize("name,ordered", [("unordered", False), ("ordered", True)])
def test_matches_rena_model_with_empty_units(name, ordered):
    case = FIXTURE[name]
    model = ENA().fit(as_accumulation(case, ordered), dims=DIMS)
    assert model.ordered_ == ordered
    assert_matches_r(model, case)


@pytest.mark.parametrize("name,ordered", [("unordered", False), ("ordered", True)])
def test_empty_units_sit_at_the_origin_with_zero_centroids(name, ordered):
    case = FIXTURE[name]
    empty = empty_rows(case)
    assert empty.sum() == (2 if not ordered else 1)
    model = ENA().fit(as_accumulation(case, ordered), dims=DIMS)
    assert (model.points_for_projection_[empty] == 0).all()
    assert (model.points_[empty] == 0).all()
    assert (model.centroids_[empty] == 0).all()
    # the centre vector is the mean of the other units' networks
    np.testing.assert_allclose(model.rotation_center_vec_, model.line_weights_[~empty].mean(axis=0), atol=1e-12)


def test_unordered_fitted_units_have_their_mean_centroid_at_the_origin():
    case = FIXTURE["unordered"]
    model = ENA().fit(as_accumulation(case, False), dims=DIMS)
    np.testing.assert_allclose(model.centroids_[~empty_rows(case)].mean(axis=0), 0, atol=1e-10)


def test_ordered_fit_equals_the_fit_without_the_empty_unit():
    case = FIXTURE["ordered"]
    keep = ~empty_rows(case)
    full = ENA().fit(as_accumulation(case, True), dims=DIMS)
    dropped = ENA().fit(as_accumulation(case, True, keep=keep), dims=DIMS)
    s = signs(dropped.points_, full.points_[keep])
    np.testing.assert_allclose(dropped.points_ * s, full.points_[keep], atol=1e-10)
    np.testing.assert_allclose(dropped.rotation_nodes_ * s, full.rotation_nodes_, atol=1e-10)
    np.testing.assert_allclose(dropped.centroids_ * s, full.centroids_[keep], atol=1e-10)


def test_no_empty_units_the_plain_fit():
    # Dropping the empty units beforehand must give the same nodes and
    # centroids for the others: the fit never saw them either way.
    case = FIXTURE["unordered"]
    keep = ~empty_rows(case)
    full = ENA().fit(as_accumulation(case, False), dims=DIMS)
    dropped = ENA().fit(as_accumulation(case, False, keep=keep), dims=DIMS)
    s = signs(dropped.points_, full.points_[keep])
    np.testing.assert_allclose(dropped.rotation_nodes_ * s, full.rotation_nodes_, atol=1e-10)
    np.testing.assert_allclose(dropped.centroids_ * s, full.centroids_[keep], atol=1e-10)
