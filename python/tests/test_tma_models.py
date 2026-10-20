"""qe-ena models TMA accumulations, as rENA's model() models tma's in R.

fixtures/tma-models.json holds rENA's model() (SVD rotation) on tma's
accumulate() of a toy data set -- ordered, unordered with self-connections
and plain unordered -- from fixtures/tma-models.R. The accumulation-shaped
tests need no qe-tma (the fixture carries R's connection counts); the
pipeline tests run qe-tma's accumulate() when it is installed.
"""
import json
from pathlib import Path
from types import SimpleNamespace

import numpy as np
import pandas as pd
import pytest

from ena import ENA

HERE = Path(__file__).parent
FIXTURE = json.loads((HERE / "fixtures/tma-models.json").read_text())
CODES = FIXTURE["codes"]
CASES = {
    "ordered":               dict(ordered=True),
    "ordered_self_weight_1": dict(ordered=True),
    "self_connections":      dict(self_connections=True),
    "plain":                 dict(),
}


def as_accumulation(case, ordered):
    """An accumulation with qe-tma's TMAAccumulation fields, from R's counts."""
    key = [list(k) for k in case["adjacency_key"]]
    return SimpleNamespace(
        connection_counts_=np.array(case["connection_counts"], dtype=float),
        unit_labels_=list(case["units"]),
        codes_=list(CODES),
        connection_names_=[f"{a} & {b}" for a, b in key],
        adjacency_key_=key,
        meta=pd.DataFrame(index=case["units"]),
        ordered_=ordered,
    )


def assert_matches_r(model, case):
    np.testing.assert_allclose(model.line_weights_, case["line_weights"], atol=1e-12)
    np.testing.assert_allclose(model.points_, case["points"], atol=1e-12)
    np.testing.assert_allclose(model.rotation_nodes_, case["nodes"], atol=1e-12)


@pytest.mark.parametrize("name", list(CASES))
def test_models_a_tma_accumulation_as_r(name):
    case = FIXTURE[name]
    accum = as_accumulation(case, CASES[name].get("ordered", False))
    model = ENA().fit(accum, self_weight=case["self_weight"])
    assert_matches_r(model, case)
    assert model.ordered_ == CASES[name].get("ordered", False)
    assert model.self_weight_ == case["self_weight"]
    assert model.rotation_adjacency_key_ == accum.adjacency_key_


def test_self_weight_moves_ordered_nodes_not_points():
    case = FIXTURE["ordered"]
    two = ENA().fit(as_accumulation(case, True))
    one = ENA().fit(as_accumulation(case, True), self_weight=1)
    np.testing.assert_allclose(two.points_, one.points_, atol=1e-12)
    assert np.abs(two.rotation_nodes_ - one.rotation_nodes_).max() > 1e-3


def test_move_nodes_follows_the_layout():
    for name in ("ordered", "self_connections"):
        case = FIXTURE[name]
        model = ENA().fit(as_accumulation(case, CASES[name].get("ordered", False)))
        moved = model.move_nodes_to_unit_circle()
        radius = np.linalg.norm(model.rotation_nodes_[:, :2], axis=1).max()
        np.testing.assert_allclose(np.linalg.norm(moved.rotation_nodes_[:, :2], axis=1), radius)


def test_standard_ena_unchanged():
    # Without ordered_ / adjacency_key_ (an ENAAccumulation's fields), the
    # standard choose(n, 2) layout and undirected solver.
    case = FIXTURE["plain"]
    accum = as_accumulation(case, False)
    del accum.ordered_, accum.adjacency_key_
    assert_matches_r(ENA().fit(accum), case)


@pytest.mark.parametrize("name", list(CASES))
def test_qe_tma_pipeline(name):
    tma = pytest.importorskip("tma")
    toy = pd.DataFrame(FIXTURE["toy"]).astype({c: float for c in CODES})
    accum = tma.accumulate(toy, "u", "c", CODES,
                           tensor=tma.context_tensor(toy, default_window=3.0),
                           weight_by="product", **CASES[name])
    case = FIXTURE[name]
    assert accum.unit_labels_ == case["units"]
    np.testing.assert_allclose(accum.connection_counts_, case["connection_counts"], atol=1e-12)
    assert_matches_r(ENA().fit(accum, self_weight=case["self_weight"]), case)
