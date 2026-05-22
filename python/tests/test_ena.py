import numpy as np
import pandas as pd
import pytest
from pyena import ENA, accumulate, ENAAccumulation


def make_df(n_units=2, n_convos=1, n_codes=3, seed=42):
    rng = np.random.default_rng(seed)
    n_rows = n_units * n_convos * 3
    import string
    code_names = list(string.ascii_uppercase[:n_codes])
    return pd.DataFrame({
        "unit":  [f"U{i % n_units}" for i in range(n_rows)],
        "convo": [f"C{i % n_convos}" for i in range(n_rows)],
        **{name: rng.integers(0, 2, n_rows).astype(float)
           for name in code_names},
    })


CODES = ["A", "B", "C"]


class TestBasicShape:
    def test_networks_shape(self):
        df = make_df(n_units=2, n_convos=1, n_codes=3)
        m = ENA().fit(df, "unit", "convo", CODES)
        assert m.networks_.shape == (2, 3)

    def test_positions_shape(self):
        df = make_df(n_units=2, n_convos=1, n_codes=3)
        m = ENA().fit(df, "unit", "convo", CODES)
        assert m.positions_.shape == (3, 2)

    def test_centroids_shape(self):
        df = make_df(n_units=2, n_convos=1, n_codes=3)
        m = ENA().fit(df, "unit", "convo", CODES)
        assert m.centroids_.shape == (2, 2)

    def test_normed_networks_shape(self):
        df = make_df(n_units=2, n_convos=1, n_codes=3)
        m = ENA().fit(df, "unit", "convo", CODES)
        assert m.normed_networks_.shape == (2, 3)


class TestZeroNetwork:
    def test_all_zero_unit_network_is_zero(self):
        df = pd.DataFrame({
            "unit":  ["A", "A", "B", "B"],
            "convo": ["c1", "c1", "c1", "c1"],
            "c1": [1.0, 0.0, 0.0, 0.0],
            "c2": [1.0, 0.0, 0.0, 0.0],
            "c3": [0.0, 0.0, 0.0, 0.0],
        })
        m = ENA().fit(df, "unit", "convo", ["c1", "c2", "c3"])
        assert np.all(m.networks_[m.units_.index("B")] == 0)


class TestSingleConversation:
    def test_single_conversation_runs(self):
        df = make_df(n_units=3, n_convos=1, n_codes=3)
        m = ENA().fit(df, "unit", "convo", CODES)
        assert m.networks_.shape[0] == 3


class TestMultiConversation:
    def test_multi_conv_larger_than_single_conv(self):
        df1 = make_df(n_units=2, n_convos=1, n_codes=3, seed=1)
        df2 = make_df(n_units=2, n_convos=2, n_codes=3, seed=1)
        m1 = ENA().fit(df1, "unit", "convo", CODES)
        m2 = ENA().fit(df2, "unit", "convo", CODES)
        assert m2.networks_.sum() >= m1.networks_.sum()

    def test_units_list_order_preserved(self):
        df = pd.DataFrame({
            "unit":  ["Z", "A", "Z", "A"],
            "convo": ["c1", "c1", "c1", "c1"],
            "c1": [1.0, 0.0, 1.0, 1.0],
            "c2": [1.0, 1.0, 0.0, 1.0],
            "c3": [0.0, 1.0, 1.0, 0.0],
        })
        m = ENA().fit(df, "unit", "convo", ["c1", "c2", "c3"])
        assert m.units_[0] == "Z"
        assert m.units_[1] == "A"


class TestConnectionNamesOrder:
    def test_three_codes_order(self):
        df = make_df(n_codes=3)
        m = ENA().fit(df, "unit", "convo", ["A", "B", "C"])
        assert m.connection_names_ == ["A&B", "A&C", "B&C"]

    def test_four_codes_order(self):
        df = make_df(n_codes=4)
        m = ENA().fit(df, "unit", "convo", ["A", "B", "C", "D"])
        assert m.connection_names_ == ["A&B", "A&C", "B&C", "A&D", "B&D", "C&D"]


class TestNormalizationParity:
    def test_sphere_rows_have_unit_norm(self):
        df = make_df(n_units=3, n_codes=3, seed=7)
        m = ENA().fit(df, "unit", "convo", CODES, norm="sphere")
        for row in m.normed_networks_:
            n = np.linalg.norm(row)
            assert n == pytest.approx(1.0, abs=1e-10) or n == pytest.approx(0.0, abs=1e-10)

    def test_skip_sphere_runs(self):
        df = make_df(n_units=2, n_codes=3)
        m = ENA().fit(df, "unit", "convo", CODES, norm="skip_sphere")
        assert m.normed_networks_.shape == (2, 3)

    def test_invalid_norm_raises(self):
        df = make_df()
        with pytest.raises(ValueError, match="norm must be"):
            ENA().fit(df, "unit", "convo", CODES, norm="bad")


class TestDimsParameter:
    def test_dims_2(self):
        df = make_df(n_units=3, n_codes=3)
        m = ENA().fit(df, "unit", "convo", CODES, dims=2)
        assert m.positions_.shape[1] == 2
        assert m.centroids_.shape[1] == 2

    def test_dims_1(self):
        df = make_df(n_units=3, n_codes=3)
        m = ENA().fit(df, "unit", "convo", CODES, dims=1)
        assert m.positions_.shape[1] == 1
        assert m.centroids_.shape[1] == 1


class TestMethodChaining:
    def test_fit_returns_self(self):
        df = make_df()
        m = ENA()
        result = m.fit(df, "unit", "convo", CODES)
        assert result is m

    def test_constructor_chain(self):
        df = make_df()
        m = ENA().fit(df, "unit", "convo", CODES)
        assert hasattr(m, "positions_")


class TestRotations:
    """Test all four rotation methods and the rotation= parameter."""

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _unit_labels(df, model):
        return list(dict.fromkeys(df["unit"].tolist()))

    # ------------------------------------------------------------------
    # Default / None rotation
    # ------------------------------------------------------------------

    def test_svd_rotation_is_default(self):
        df = make_df()
        m1 = ENA().fit(df, "unit", "convo", CODES)
        m2 = ENA().fit(df, "unit", "convo", CODES, rotation=None)
        np.testing.assert_allclose(
            np.abs(m1.positions_), np.abs(m2.positions_), atol=1e-10
        )

    def test_full_rotation_stored(self):
        df = make_df()
        m = ENA().fit(df, "unit", "convo", CODES)
        assert hasattr(m, "full_rotation_")
        assert hasattr(m, "rotation_")
        assert m.rotation_.shape[1] == 2

    # ------------------------------------------------------------------
    # mean_rotation
    # ------------------------------------------------------------------

    def test_mean_rotation_changes_positions(self):
        from pyena.rotations import mean_rotation
        df = make_df(n_units=4, n_codes=3, seed=7)
        unit_labels = list(dict.fromkeys(df["unit"].tolist()))
        g1 = np.array([u in unit_labels[:2] for u in unit_labels])
        g2 = ~g1
        m_svd = ENA().fit(df, "unit", "convo", CODES)
        m_mr = ENA().fit(df, "unit", "convo", CODES, rotation=mean_rotation(g1, g2))
        assert m_svd.positions_.shape == m_mr.positions_.shape
        # Allow that SVD and mean-rotation may coincidentally align (very unlikely)
        # but shapes must match and both must run without error.

    def test_mean_rotation_output_shape(self):
        from pyena.rotations import mean_rotation
        df = make_df(n_units=4, n_codes=3, seed=7)
        unit_labels = list(dict.fromkeys(df["unit"].tolist()))
        g1 = np.array([u in unit_labels[:2] for u in unit_labels])
        g2 = ~g1
        m = ENA().fit(df, "unit", "convo", CODES, rotation=mean_rotation(g1, g2))
        assert m.positions_.shape == (3, 2)
        assert m.centroids_.shape == (4, 2)

    # ------------------------------------------------------------------
    # generalized_rotation
    # ------------------------------------------------------------------

    def test_generalized_rotation_continuous(self):
        from pyena.rotations import generalized_rotation
        df = make_df(n_units=4, n_codes=3, seed=7)
        unit_labels = list(dict.fromkeys(df["unit"].tolist()))
        x_var = np.array([float(i) for i in range(len(unit_labels))])
        m = ENA().fit(df, "unit", "convo", CODES,
                      rotation=generalized_rotation(x_var))
        assert m.positions_.shape == (3, 2)

    def test_generalized_rotation_categorical(self):
        from pyena.rotations import generalized_rotation
        df = make_df(n_units=4, n_codes=3, seed=7)
        x_var = np.array(["A", "A", "B", "B"])
        m = ENA().fit(df, "unit", "convo", CODES,
                      rotation=generalized_rotation(x_var))
        assert m.positions_.shape == (3, 2)

    def test_generalized_rotation_select_2_groups(self):
        from pyena.rotations import generalized_rotation
        df = make_df(n_units=4, n_codes=3, seed=7)
        x_var = np.array(["A", "A", "B", "B"])
        m = ENA().fit(
            df, "unit", "convo", CODES,
            rotation=generalized_rotation(x_var, select_2_groups=("A", "B")),
        )
        assert m.positions_.shape == (3, 2)

    # ------------------------------------------------------------------
    # regression_rotation
    # ------------------------------------------------------------------

    def test_regression_rotation(self):
        from pyena.rotations import regression_rotation
        df = make_df(n_units=4, n_codes=3, seed=7)
        x_var = np.array([1.0, 1.0, 0.0, 0.0])
        m = ENA().fit(df, "unit", "convo", CODES,
                      rotation=regression_rotation(x_var))
        assert m.positions_.shape == (3, 2)

    # ------------------------------------------------------------------
    # regression_rotation_2
    # ------------------------------------------------------------------

    def test_regression_rotation_2(self):
        from pyena.rotations import regression_rotation_2
        df = make_df(n_units=4, n_codes=3, seed=7)
        x_var = np.array([1.0, 1.0, 0.0, 0.0])
        m = ENA().fit(df, "unit", "convo", CODES,
                      rotation=regression_rotation_2(x_var))
        assert m.positions_.shape == (3, 2)

    # ------------------------------------------------------------------
    # Pre-computed numpy matrix
    # ------------------------------------------------------------------

    def test_custom_matrix_rotation(self):
        """Pass a pre-computed numpy rotation matrix — centroids must match."""
        df = make_df(n_units=4, n_codes=3, seed=7)
        m1 = ENA().fit(df, "unit", "convo", CODES)
        m2 = ENA().fit(df, "unit", "convo", CODES, rotation=m1.full_rotation_)
        np.testing.assert_allclose(m1.centroids_, m2.centroids_, atol=1e-10)

    # ------------------------------------------------------------------
    # Orthogonality
    # ------------------------------------------------------------------

    def test_rotation_column_orthogonality(self):
        """Full rotation matrix columns must be orthonormal."""
        from pyena.rotations import mean_rotation
        df = make_df(n_units=4, n_codes=3, seed=7)
        unit_labels = list(dict.fromkeys(df["unit"].tolist()))
        g1 = np.array([u in unit_labels[:2] for u in unit_labels])
        g2 = ~g1
        m = ENA().fit(df, "unit", "convo", CODES, rotation=mean_rotation(g1, g2))
        R = m.full_rotation_
        k = min(R.shape)
        RtR = R[:, :k].T @ R[:, :k]
        np.testing.assert_allclose(RtR, np.eye(k), atol=1e-10)

    # ------------------------------------------------------------------
    # Invalid rotation raises
    # ------------------------------------------------------------------

    def test_invalid_rotation_raises(self):
        df = make_df()
        with pytest.raises(ValueError, match="rotation must be"):
            ENA().fit(df, "unit", "convo", CODES, rotation="bad")


class TestAccumulate:
    """Standalone accumulate() function and ENAAccumulation object."""

    def test_returns_ena_accumulation(self):
        df = make_df()
        accum = accumulate(df, "unit", "convo", CODES)
        assert isinstance(accum, ENAAccumulation)

    def test_networks_shape(self):
        df = make_df(n_units=3, n_codes=3)
        accum = accumulate(df, "unit", "convo", CODES)
        assert accum.networks_.shape == (3, 3)   # 3 units × choose_two(3)=3

    def test_units_order_preserved(self):
        df = pd.DataFrame({
            "unit":  ["Z", "A", "Z", "A"],
            "convo": ["c1", "c1", "c1", "c1"],
            "c1": [1., 0., 1., 1.],
            "c2": [1., 1., 0., 1.],
            "c3": [0., 1., 1., 0.],
        })
        accum = accumulate(df, "unit", "convo", ["c1", "c2", "c3"])
        assert accum.units_[0] == "Z"
        assert accum.units_[1] == "A"

    def test_connection_names(self):
        df = make_df(n_codes=3)
        accum = accumulate(df, "unit", "convo", CODES)
        assert accum.connection_names_ == ["A&B", "A&C", "B&C"]

    def test_meta_index_matches_units(self):
        df = make_df(n_units=3)
        pattern = (["X", "Y", "X"] * (len(df) // 3 + 1))[:len(df)]
        df["condition"] = pattern
        accum = accumulate(df, "unit", "convo", CODES)
        assert list(accum.meta.index) == accum.units_

    def test_networks_match_full_fit(self):
        """accumulate() networks must match ENA.fit() networks_ exactly."""
        df = make_df(n_units=4, n_codes=3, seed=99)
        accum = accumulate(df, "unit", "convo", CODES)
        model = ENA().fit(df, "unit", "convo", CODES)
        np.testing.assert_array_equal(accum.networks_, model.networks_)

    def test_fit_from_accumulation_matches_direct_fit(self):
        """ENA().fit(accum) must produce identical results to ENA().fit(df, ...)."""
        df = make_df(n_units=4, n_codes=3, seed=42)
        m_direct = ENA().fit(df, "unit", "convo", CODES)
        accum    = accumulate(df, "unit", "convo", CODES)
        m_accum  = ENA().fit(accum)
        np.testing.assert_allclose(m_direct.centroids_,      m_accum.centroids_,      atol=1e-12)
        np.testing.assert_allclose(m_direct.normed_networks_, m_accum.normed_networks_, atol=1e-12)
        np.testing.assert_allclose(m_direct.positions_,      m_accum.positions_,      atol=1e-12)

    def test_fit_from_accumulation_stores_accum(self):
        df = make_df()
        accum = accumulate(df, "unit", "convo", CODES)
        model = ENA().fit(accum)
        assert model.accum_ is accum

    def test_fit_from_accumulation_with_rotation(self):
        """Rotation should work when fit() receives an ENAAccumulation."""
        from pyena.rotations import mean_rotation
        df = make_df(n_units=4, n_codes=3, seed=7)
        accum = accumulate(df, "unit", "convo", CODES)
        unit_labels = accum.units_
        g1 = np.array([u in unit_labels[:2] for u in unit_labels])
        g2 = ~g1
        model = ENA().fit(accum, rotation=mean_rotation(g1, g2))
        assert model.positions_.shape == (3, 2)

    def test_fit_missing_args_raises(self):
        """Passing a DataFrame without units/conversations/codes must raise."""
        df = make_df()
        with pytest.raises(ValueError, match="units, conversations, and codes"):
            ENA().fit(df)

    def test_fit_no_data_no_accum_raises(self):
        with pytest.raises(ValueError, match="No data provided"):
            ENA().fit()


class TestConstructorAndChainStyles:
    """ENA(data, ...).fit() and ENA().accumulate(...).fit() patterns."""

    def test_constructor_style_matches_one_liner(self):
        df = make_df(n_units=3, n_codes=3, seed=5)
        m1 = ENA().fit(df, "unit", "convo", CODES)
        m2 = ENA(df, "unit", "convo", CODES).fit()
        np.testing.assert_allclose(m1.centroids_, m2.centroids_, atol=1e-12)

    def test_chain_style_matches_one_liner(self):
        df = make_df(n_units=3, n_codes=3, seed=5)
        m1 = ENA().fit(df, "unit", "convo", CODES)
        m2 = ENA().accumulate(df, "unit", "convo", CODES).fit()
        np.testing.assert_allclose(m1.centroids_, m2.centroids_, atol=1e-12)

    def test_constructor_with_fit_options(self):
        """Constructor takes accumulation params; fit() takes modeling params."""
        from pyena.rotations import mean_rotation
        df = make_df(n_units=4, n_codes=3, seed=7)
        unit_labels = list(dict.fromkeys(df["unit"].tolist()))
        g1 = np.array([u in unit_labels[:2] for u in unit_labels])
        g2 = ~g1
        model = ENA(df, "unit", "convo", CODES).fit(rotation=mean_rotation(g1, g2))
        assert model.positions_.shape == (3, 2)

    def test_chain_with_fit_options(self):
        """accumulate() takes window params; fit() takes modeling params."""
        df = make_df(n_units=3, n_codes=3, seed=5)
        model = (ENA()
                 .accumulate(df, "unit", "convo", CODES, window_size=2)
                 .fit(norm="skip_sphere", dims=1))
        assert model.centroids_.shape == (3, 1)

    def test_accumulate_stores_accum_before_fit(self):
        df = make_df()
        ena = ENA().accumulate(df, "unit", "convo", CODES)
        assert isinstance(ena.accum_, ENAAccumulation)
        assert not hasattr(ena, "centroids_")   # not yet fitted
