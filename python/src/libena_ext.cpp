// _libena — nanobind bindings for libena, the ENA C++ layer (inst/include/libena).
//
// Also registers the libtma function qe-ena uses (accumulate_stanza, for
// ena/accumulation.py), from libtma's shared bindings.
//
// One flat module, imported by ena/libena.py, which wraps the plain-data
// results (dicts of numpy arrays, from libena/bind/nanobind.hpp) in Python
// result classes.  Function bodies and docstrings moved from qe-lib's qe.cpp
// (libqe's phase 4a split); results are dicts instead of registered classes so
// this module can be loaded alongside other products' extensions.
//
// All matrix arguments are accepted as 2-D numpy float64 arrays (C-contiguous).
// All vector arguments are accepted as 1-D numpy float64 arrays.
// Return values are always freshly allocated numpy arrays (owned by Python).

#include <nanobind/nanobind.h>
#include <nanobind/ndarray.h>
#include <nanobind/stl/string.h>
#include <nanobind/stl/vector.h>

#include <armadillo>
#include <libqe/validate.hpp>
#include <libqe/bind/nanobind.hpp>
#include <libena/generalized_rotation.hpp>
#include <libena/bind/nanobind.hpp>
#include <libtma/bind/nanobind.hpp>

namespace nb = nanobind;
using namespace nb::literals;

// to_mat / from_mat / ... (libqe/bind/nanobind.hpp) and to_dict for libena
// results (libena/bind/nanobind.hpp).
using namespace qe::bind::py;

NB_MODULE(_libena, m) {
    m.doc() = "_libena — nanobind bindings for libena (ENA rotations, node positions, CCD)";

    m.def("ena_correlation", [](NpMat points, NpMat centroids, double conf_level) {
        return from_mat(qe::ena_correlation(to_mat(points), to_mat(centroids), conf_level));
    }, "points"_a, "centroids"_a, "conf_level"_a = 0.95,
        "Pearson correlation + CI between unit points and centroids.\n"
        "Returns (n_dims × 3) array: columns are [r, ci_lower, ci_upper].");

    m.def("node_positions", [](NpMat adj_mats, NpMat t, int num_dims) {
        arma::mat am = to_mat(adj_mats);
        arma::mat tv = to_mat(t);
        qe::require_finite(am, "adj_mats");
        qe::require_finite(tv, "t");
        return to_dict(qe::node_positions(am, tv, num_dims));
    }, "adj_mats"_a, "t"_a, "num_dims"_a,
        "Multiobjective least-squares node positions for undirected ENA.");

    m.def("directed_node_positions", [](NpMat line_weights, NpMat points, int num_dims) {
        arma::mat lw = to_mat(line_weights);
        arma::mat pt = to_mat(points);
        qe::require_finite(lw, "line_weights");
        qe::require_finite(pt, "points");
        return to_dict(qe::directed_node_positions(lw, pt, num_dims));
    }, "line_weights"_a, "points"_a, "num_dims"_a,
        "Least-squares node positions for directed (ordered) ENA.");

    m.def("directed_node_positions_combine_pairs",
        [](NpMat line_weights, NpMat points, int num_dims) {
            arma::mat lw = to_mat(line_weights);
            arma::mat pt = to_mat(points);
            qe::require_finite(lw, "line_weights");
            qe::require_finite(pt, "points");
            return to_dict(qe::directed_node_positions(lw, pt, num_dims, true));
        }, "line_weights"_a, "points"_a, "num_dims"_a,
        "Directed node positions with paired ground+response rows combined before solving.");

    m.def("ena_svd", [](NpMat points) {
        arma::mat pt = to_mat(points);
        qe::require_finite(pt, "points");
        return to_dict(qe::ena_svd(pt));
    }, "points"_a,
        "SVD rotation matching prcomp(retx=F, scale=F, center=F, tol=0).\n\n"
        "Caller is responsible for centering upstream. Eigenvalues are stored\n"
        "as sdev^2 to match rENA's ena.svd.\n\n"
        "Parameters\n----------\n"
        "points : ndarray (n_units × n_dims)\n\n"
        "Returns RotationResult with column_names = ['SVD1', ..., 'SVDp'].\n\n"
        "Sign convention: none. Signs come from LAPACK's SVD, matching rENA's\n"
        "long-standing behavior. A deterministic sign rule may be added later.");

    m.def("deflate", [](NpMat data, NpVec axis) {
        return from_mat(qe::deflate(to_mat(data), to_vec(axis)));
    }, "data"_a, "axis"_a,
        "Project `data` onto the hyperplane orthogonal to a unit-norm axis:\n"
        "  data - (data @ axis) @ axis.T\n\n"
        "Caller is responsible for normalizing `axis`.\n\n"
        "Returns a matrix of the same shape as `data`.");

    m.def("orthogonal_svd",
        [](NpMat data, NpMat weights,
                       std::vector<std::string> named_labels) {
            return to_dict(qe::orthogonal_svd(
                to_mat(data), to_mat(weights), named_labels));
        },
        "data"_a, "weights"_a, "named_labels"_a,
        "Orthonormalize named axes via QR, fill the rest from SVD.\n\n"
        "Mirrors rENA's orthogonal_svd() in ena.rotate.by.mean.R. The named\n"
        "axes in the OUTPUT are the orthonormalized Q columns, not the\n"
        "original `weights` columns — use complete_rotation() to keep the\n"
        "named axes verbatim.\n\n"
        "Parameters\n----------\n"
        "data         : ndarray (n_units × n_dims)\n"
        "weights      : ndarray (n_dims × k)   — columns are the named axes\n"
        "named_labels : list[str] of length k  — labels for the named axes\n\n"
        "Returns RotationResult with column_names = named_labels + ['SVD{k+1}'..'SVDp'].");

    m.def("complete_rotation",
        [](NpMat data, NpMat named_axes,
                       std::vector<std::string> named_labels) {
            return to_dict(qe::complete_rotation(
                to_mat(data), to_mat(named_axes), named_labels));
        },
        "data"_a, "named_axes"_a, "named_labels"_a,
        "Keep named axes verbatim, fill remaining axes from an SVD of the\n"
        "data deflated by all named axes in parallel:\n"
        "  defA = data - data @ named_axes @ named_axes.T\n\n"
        "Mirrors the tail of ena.rotate.by.generalized (canonical version:\n"
        "commit 2c079126 on rENA origin/main). The deflation is *parallel*\n"
        "(each projection comes off the original data), matching rENA's\n"
        "literal expression `defA <- A - A %*% v1 %*% t(v1) - A %*% v2 %*% t(v2)`.\n"
        "For mutually orthogonal axes this equals sequential deflation.\n"
        "On rank-deficient data (e.g. an all-zero connection column) the\n"
        "trailing axes that come from the deflated data's null space are\n"
        "orthogonalised against the named axes, so the rotation is orthonormal\n"
        "whenever the named axes are.\n\n"
        "Caller is responsible for ensuring each column of `named_axes` is\n"
        "unit-norm. Orthonormality between columns is NOT assumed.\n\n"
        "Conventional labels for generalized rotation are 'GMR1', 'GMR2',\n"
        "then 'SVD{k+1}'..'SVDp'.");

    m.def("means_rotation",
        [](NpMat points, nb::list group_pairs) {
            std::vector<qe::GroupPair> pairs;
            pairs.reserve(group_pairs.size());
            for (std::size_t i = 0; i < group_pairs.size(); ++i) {
                nb::sequence pair = nb::cast<nb::sequence>(group_pairs[i]);
                if (nb::len(pair) != 2) {
                    throw std::runtime_error(
                        "group_pairs[" + std::to_string(i) +
                        "] must be a length-2 sequence (a, b)");
                }
                auto seq_to_uvec = [](nb::handle h) {
                    auto seq = nb::cast<nb::sequence>(h);
                    arma::uvec out(nb::len(seq));
                    std::size_t k = 0;
                    for (nb::handle item : seq) {
                        out(k++) = nb::cast<arma::uword>(item);
                    }
                    return out;
                };
                pairs.push_back({ seq_to_uvec(pair[0]), seq_to_uvec(pair[1]) });
            }
            return to_dict(qe::means_rotation(to_mat(points), pairs));
        },
        "points"_a, "group_pairs"_a,
        "Means rotation matching ena.rotate.by.mean.\n\n"
        "For each group pair, computes a normalized mean-difference axis on\n"
        "the progressively-deflated data and finishes with orthogonal_svd.\n"
        "The input is column-centered first, matching rENA's\n"
        "  scale(data, scale=F, center=T)\n"
        "at the top of ena.rotate.by.mean.\n\n"
        "Parameters\n----------\n"
        "points      : ndarray (n_units × n_dims)\n"
        "group_pairs : list of length k; each element is (a, b) where a and\n"
        "              b are 0-based integer index sequences into `points`.\n\n"
        "Returns RotationResult with column_names = ['MR1', ..., 'MRk',\n"
        "'SVD{k+1}', ..., 'SVDp'].\n\n"
        "MATCH-RENA NOTE: no guard against zero-norm mean-difference vectors\n"
        "(latent bug carried forward from rENA verbatim).");

    m.def("generalized_means_rotation",
        [](NpMat V,
                      NpMat x_model, NpVec x_target,
                      std::vector<int> x1_cols,
                      bool x_categorical, int x_n_groups,
                      std::vector<int> x_subset,
                      bool has_y,
                      NpMat y_model, NpVec y_target,
                      std::vector<int> y1_cols,
                      bool y_categorical, int y_n_groups,
                      int n_lambda, int k_folds, double lasso_eps) {
            auto to_uvec = [](const std::vector<int>& v) {
                arma::uvec out(v.size());
                for (std::size_t i = 0; i < v.size(); ++i)
                    out(i) = static_cast<arma::uword>(v[i]);
                return out;
            };

            qe::GeneralizedRotationParams p;
            p.x_model_matrix = to_mat(x_model);
            p.x_target       = to_vec(x_target);
            p.x1_cols        = to_uvec(x1_cols);
            p.x_categorical  = x_categorical;
            p.x_n_groups     = static_cast<arma::uword>(x_n_groups);
            p.x_subset       = to_uvec(x_subset);   // empty list → use all rows
            p.has_y          = has_y;
            p.y_model_matrix = to_mat(y_model);
            p.y_target       = to_vec(y_target);
            p.y1_cols        = to_uvec(y1_cols);
            p.y_categorical  = y_categorical;
            p.y_n_groups     = static_cast<arma::uword>(y_n_groups);
            p.n_lambda       = n_lambda;
            p.k_folds        = k_folds;
            p.lasso_eps      = lasso_eps;

            return to_dict(qe::generalized_means_rotation(to_mat(V), p));
        },
        "V"_a, "x_model"_a, "x_target"_a, "x1_cols"_a,
        "x_categorical"_a, "x_n_groups"_a, "x_subset"_a,
        "has_y"_a,
        "y_model"_a, "y_target"_a, "y1_cols"_a,
        "y_categorical"_a, "y_n_groups"_a,
        "n_lambda"_a=50, "k_folds"_a=5, "lasso_eps"_a=0.01,
        "Generalized Means Rotation (GMR) with Lasso-based covariate adjustment.\n\n"
        "Mirrors rENA's ``ena.rotate.by.generalized()``. The x axis is the direction\n"
        "in ENA space most explained by ``x_target`` after controlling for covariates\n"
        "via Lasso (coordinate-descent, k-fold CV). The y axis is either a second GMR\n"
        "axis (``has_y=True``) or the leading SVD of the x-deflated space.\n\n"
        "All index lists (``x1_cols``, ``x_subset``, ``y1_cols``) are **0-based int**.\n"
        "Pass an empty list ``[]`` for ``x_subset`` to use all rows.\n"
        "Pass empty arrays/lists for all ``y_*`` arguments when ``has_y=False``.\n\n"
        "Parameters\n----------\n"
        "V            : ndarray (n_units × n_dims)   ENA point matrix\n"
        "x_model      : ndarray (n_units × p)        model matrix for x axis\n"
        "x_target     : ndarray (n_units,)            target variable\n"
        "x1_cols      : list[int]  0-based target column indices in x_model\n"
        "x_categorical: bool\n"
        "x_n_groups   : int   number of groups (only used when x_categorical=True)\n"
        "x_subset     : list[int]  0-based row indices; [] = use all rows\n"
        "has_y        : bool  True → compute second GMR axis; False → SVD fallback\n"
        "y_model      : ndarray (n_units × p)  (ignored when has_y=False)\n"
        "y_target     : ndarray (n_units,)     (ignored when has_y=False)\n"
        "y1_cols      : list[int]              (ignored when has_y=False)\n"
        "y_categorical: bool                   (ignored when has_y=False)\n"
        "y_n_groups   : int                    (ignored when has_y=False)\n"
        "n_lambda     : int    lambda path length (default 50)\n"
        "k_folds      : int    CV folds for lambda selection (default 5)\n"
        "lasso_eps    : float  lambda_min = lasso_eps * lambda_max (default 0.01)\n\n"
        "Returns RotationResult with column_names = ['GMR1', 'GMR2'|'SVD2',\n"
        "'SVD3', ..., 'SVDp'].\n\n"
        "Reference: Zhiqiang Cai, commit 46776a1981a90b3a3b2861ed1010e9dbb7acf901.");

    m.def("ccd_window", [](nb::list conversations, int max_window, int min_overlap) {
        std::vector<arma::mat> convos;
        convos.reserve(conversations.size());
        for (auto item : conversations) {
            NpMat arr = nb::cast<NpMat>(item);
            convos.push_back(to_mat(arr));
        }
        return to_dict(qe::ccd_window(convos, max_window, min_overlap));
    }, "conversations"_a, "max_window"_a = 20, "min_overlap"_a = 10);

    // ── libtma: the accumulation qe-ena uses ──────────────────────────────────
    // The binding is libtma's own (libtma/bind/nanobind.hpp, shared with
    // qe-tma's tma._libtma): rENA compiles the libtma it needs, so qe-ena does
    // not depend on qe-tma (which depends on qe-ena).
    def_accumulate_stanza(m);
}
