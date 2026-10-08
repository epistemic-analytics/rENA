// libena Julia bindings via CxxWrap.jl (the ENA.jl package).
//
// libena is the ENA C++ layer (inst/include/libena): rotations, node
// positions and CCD window estimation.  These methods moved from LibQE.jl's
// libqe_julia.cpp (libqe's phase 4a split) with the same signatures and
// bodies, except that results are plain tuples (libena/bind/cxxwrap.hpp)
// instead of add_type structs, so this module loads alongside other
// products' modules.  src/ENA.jl turns them into NamedTuples.
//
// Julia matrices are column-major, like Armadillo's, so inputs are zero-copy
// views (view_mat); results are copied out once to std::vector<double>.

#include <jlcxx/jlcxx.hpp>
#include <jlcxx/array.hpp>
#include <jlcxx/stl.hpp>

#include <armadillo>
#include <libena/rotation.hpp>
#include <libena/generalized_rotation.hpp>
#include <libena/positions.hpp>
#include <libena/ccd.hpp>
#include <libqe/bind/cxxwrap.hpp>
#include <libena/bind/cxxwrap.hpp>

#include <cstddef>
#include <stdexcept>
#include <string>
#include <vector>

// view_mat / pack (libqe/bind/cxxwrap.hpp) and to_tuple for libena results
// (libena/bind/cxxwrap.hpp).
using namespace qe::bind::jl;

JLCXX_MODULE define_julia_module(jlcxx::Module& mod) {

    // ── Modeling: correlation and node positions ──────────────────────────────

    // ena_correlation → n_units × 3 [r, lower, upper]
    mod.method("ena_correlation",
        [](jlcxx::ArrayRef<double> pts, int32_t pr, int32_t pc,
           jlcxx::ArrayRef<double> cen, int32_t cr, int32_t cc,
           double conf_level) -> std::vector<double> {
            return pack(qe::ena_correlation(view_mat(pts, pr, pc),
                                            view_mat(cen, cr, cc), conf_level));
        });

    mod.method("node_positions",
        [](jlcxx::ArrayRef<double> adj, int32_t ar, int32_t ac,
           jlcxx::ArrayRef<double> t,   int32_t tr, int32_t tc,
           int32_t num_dims) -> NodePositionsTuple {
            return to_tuple(qe::node_positions(
                view_mat(adj, ar, ac), view_mat(t, tr, tc), num_dims));
        });

    mod.method("directed_node_positions",
        [](jlcxx::ArrayRef<double> lw, int32_t lr, int32_t lc,
           jlcxx::ArrayRef<double> pt, int32_t pr, int32_t pc,
           int32_t num_dims) -> NodePositionsTuple {
            return to_tuple(qe::directed_node_positions(
                view_mat(lw, lr, lc), view_mat(pt, pr, pc), num_dims));
        });

    mod.method("directed_node_positions_combine_pairs",
        [](jlcxx::ArrayRef<double> lw, int32_t lr, int32_t lc,
           jlcxx::ArrayRef<double> pt, int32_t pr, int32_t pc,
           int32_t num_dims) -> NodePositionsTuple {
            return to_tuple(qe::directed_node_positions(
                view_mat(lw, lr, lc), view_mat(pt, pr, pc), num_dims, true));
        });

    // ── Rotation ──────────────────────────────────────────────────────────────

    mod.method("ena_svd",
        [](jlcxx::ArrayRef<double> m, int32_t rows, int32_t cols) -> RotationTuple {
            return to_tuple(qe::ena_svd(view_mat(m, rows, cols)));
        });

    mod.method("deflate",
        [](jlcxx::ArrayRef<double> m, int32_t rows, int32_t cols,
           jlcxx::ArrayRef<double> axis_ref) -> std::vector<double> {
            arma::vec axis(axis_ref.data(), axis_ref.size(), false, true);
            return pack(qe::deflate(view_mat(m, rows, cols), axis));
        });

    mod.method("orthogonal_svd",
        [](jlcxx::ArrayRef<double> data,    int32_t dr, int32_t dc,
           jlcxx::ArrayRef<double> weights, int32_t wr, int32_t wc,
           const std::vector<std::string>& labels) -> RotationTuple {
            return to_tuple(qe::orthogonal_svd(
                view_mat(data,    dr, dc),
                view_mat(weights, wr, wc),
                labels));
        });

    mod.method("complete_rotation",
        [](jlcxx::ArrayRef<double> data,  int32_t dr, int32_t dc,
           jlcxx::ArrayRef<double> axes,  int32_t ar, int32_t ac,
           const std::vector<std::string>& labels) -> RotationTuple {
            return to_tuple(qe::complete_rotation(
                view_mat(data, dr, dc),
                view_mat(axes, ar, ac),
                labels));
        });

    // means_rotation — group pairs passed as four flat vectors:
    //   a_flat / a_sizes: concatenated a-group indices + size of each group
    //   b_flat / b_sizes: same for b-groups
    // Julia wrapper reconstructs Vector{Tuple{Vector{Int32},Vector{Int32}}} → these.
    mod.method("means_rotation",
        [](jlcxx::ArrayRef<double> m, int32_t rows, int32_t cols,
           const std::vector<int32_t>& a_flat, const std::vector<int32_t>& a_sizes,
           const std::vector<int32_t>& b_flat, const std::vector<int32_t>& b_sizes)
           -> RotationTuple {

            std::vector<qe::GroupPair> pairs;
            pairs.reserve(a_sizes.size());
            size_t ai = 0, bi = 0;
            for (size_t k = 0; k < a_sizes.size(); ++k) {
                arma::uvec a(static_cast<arma::uword>(a_sizes[k]));
                arma::uvec b(static_cast<arma::uword>(b_sizes[k]));
                for (arma::uword j = 0; j < a.n_elem; ++j)
                    a(j) = static_cast<arma::uword>(a_flat[ai++]);
                for (arma::uword j = 0; j < b.n_elem; ++j)
                    b(j) = static_cast<arma::uword>(b_flat[bi++]);
                pairs.push_back({a, b});
            }
            return to_tuple(qe::means_rotation(view_mat(m, rows, cols), pairs));
        });

    // generalized_means_rotation — Lasso-based GMR.
    // Index vectors (x1_cols, x_subset, y1_cols) are 0-based Int32 vectors.
    // Pass an empty vector for x_subset to use all rows.
    mod.method("generalized_means_rotation",
        [](jlcxx::ArrayRef<double> V,  int32_t vr, int32_t vc,
           jlcxx::ArrayRef<double> xm, int32_t xr, int32_t xc,
           jlcxx::ArrayRef<double> x_target,
           const std::vector<int32_t>& x1_cols_v,
           bool x_categorical, int32_t x_n_groups,
           const std::vector<int32_t>& x_subset_v,
           bool has_y,
           jlcxx::ArrayRef<double> ym, int32_t yr, int32_t yc,
           jlcxx::ArrayRef<double> y_target,
           const std::vector<int32_t>& y1_cols_v,
           bool y_categorical, int32_t y_n_groups,
           int32_t n_lambda, int32_t k_folds, double lasso_eps)
           -> RotationTuple {

            auto to_uvec = [](const std::vector<int32_t>& v) {
                arma::uvec out(v.size());
                for (size_t i = 0; i < v.size(); ++i)
                    out(i) = static_cast<arma::uword>(v[i]);
                return out;
            };
            auto ref_to_vec = [](jlcxx::ArrayRef<double> a) {
                return arma::vec(a.data(), a.size());
            };

            qe::GeneralizedRotationParams p;
            p.x_model_matrix = view_mat(xm, xr, xc);
            p.x_target       = ref_to_vec(x_target);
            p.x1_cols        = to_uvec(x1_cols_v);
            p.x_categorical  = x_categorical;
            p.x_n_groups     = static_cast<arma::uword>(x_n_groups);
            p.x_subset       = to_uvec(x_subset_v);   // empty → use all rows
            p.has_y          = has_y;
            p.y_model_matrix = view_mat(ym, yr, yc);
            p.y_target       = ref_to_vec(y_target);
            p.y1_cols        = to_uvec(y1_cols_v);
            p.y_categorical  = y_categorical;
            p.y_n_groups     = static_cast<arma::uword>(y_n_groups);
            p.n_lambda       = static_cast<int>(n_lambda);
            p.k_folds        = static_cast<int>(k_folds);
            p.lasso_eps      = lasso_eps;

            return to_tuple(qe::generalized_means_rotation(view_mat(V, vr, vc), p));
        });

    // ── CCD window-size estimation ────────────────────────────────────────────
    // Conversations arrive as one column-major block per conversation,
    // concatenated in `data`, with each block's row count in `rows` (all share
    // `n_codes` columns).  Not bound by LibQE.jl; added with the move.
    mod.method("ccd_window",
        [](jlcxx::ArrayRef<double> data, const std::vector<int32_t>& rows,
           int32_t n_codes, int32_t max_window, int32_t min_overlap) -> CCDTuple {
            std::vector<arma::mat> convos;
            convos.reserve(rows.size());
            std::size_t offset = 0;
            for (int32_t r : rows) {
                convos.emplace_back(data.data() + offset,
                                    static_cast<arma::uword>(r),
                                    static_cast<arma::uword>(n_codes));
                offset += static_cast<std::size_t>(r) * static_cast<std::size_t>(n_codes);
            }
            if (offset != data.size())
                throw std::invalid_argument(
                    "ccd_window: data length does not match sum(rows) * n_codes");
            return to_tuple(qe::ccd_window(convos, max_window, min_overlap));
        });
}
