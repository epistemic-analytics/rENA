// libena WebAssembly bindings via Emscripten Embind.
//
// libena is the ENA C++ layer (inst/include/libena): rotations, node
// positions and CCD window estimation.  These functions moved here from
// libqe-wasm (libqe's phase 4a split) with the same signatures and bodies;
// rena-wasm's src/index.js routes them to this module and everything else
// to @qe-libs/libqe-wasm.
//
// Matrix convention (as libqe-wasm): every matrix argument is a flat
// Float64Array (row-major) plus explicit rows/cols; results are plain JS
// objects, matrices as { data: Float64Array, rows: number, cols: number }.
//
// Disable BLAS/LAPACK — Armadillo falls back to its own built-in routines,
// which compile cleanly with Emscripten.

#ifndef ARMA_DONT_USE_BLAS
#  define ARMA_DONT_USE_BLAS
#endif
#ifndef ARMA_DONT_USE_LAPACK
#  define ARMA_DONT_USE_LAPACK
#endif

#include <armadillo>
#include <libena/rotation.hpp>
#include <libena/generalized_rotation.hpp>
#include <libena/positions.hpp>
#include <libena/ccd.hpp>
#include <emscripten/bind.h>
#include <emscripten/val.h>
#include <libqe/bind/emscripten.hpp>
#include <libena/bind/emscripten.hpp>
#include <vector>
#include <string>

using namespace emscripten;

// Array conversion (js_to_mat, mat_to_js, …) comes from
// libqe/bind/emscripten.hpp; result packing (to_js) from
// libena/bind/emscripten.hpp.
using namespace qe::bind::js;

// ── Modeling: correlation and node positions ──────────────────────────────────

// ena_correlation(pts, pt_rows, pt_cols, cen, cen_rows, cen_cols, conf_level)
// → { data, rows:n_units, cols:3 }  columns: [r, ci_lower, ci_upper]
static val ena_correlation(const val& pts, int pt_rows, int pt_cols,
                            const val& cen, int cen_rows, int cen_cols,
                            double conf_level) {
    return mat_to_js(qe::ena_correlation(
        js_to_mat(pts, pt_rows, pt_cols),
        js_to_mat(cen, cen_rows, cen_cols),
        conf_level));
}

// node_positions(adj_data, adj_rows, adj_cols,
//                t_data,   t_rows,   t_cols [, num_dims])
// → { nodes, centroids, weights, points }  (each a matrix object)
//
// num_dims: how many columns of t to project onto.  If omitted or <= 0,
// defaults to t_cols (use all dimensions).  Embind passes 0 for missing
// integer arguments, so this default covers the "caller forgot num_dims" case.
static val node_positions(const val& adj_data, int adj_rows, int adj_cols,
                           const val& t_data,   int t_rows,   int t_cols,
                           int num_dims) {
    arma::mat t = js_to_mat(t_data, t_rows, t_cols);
    if (num_dims <= 0) num_dims = static_cast<int>(t.n_cols);
    return to_js(qe::node_positions(
        js_to_mat(adj_data, adj_rows, adj_cols),
        t,
        num_dims));
}

// directed_node_positions — same signature as node_positions
static val directed_node_positions(const val& lw_data, int lw_rows, int lw_cols,
                                    const val& pt_data,  int pt_rows, int pt_cols,
                                    int num_dims) {
    arma::mat pt = js_to_mat(pt_data, pt_rows, pt_cols);
    if (num_dims <= 0) num_dims = static_cast<int>(pt.n_cols);
    return to_js(qe::directed_node_positions(
        js_to_mat(lw_data, lw_rows, lw_cols),
        pt,
        num_dims));
}

// directed_node_positions_combine_pairs — ground+response rows combined before solve
static val directed_node_positions_combine_pairs(
        const val& lw_data, int lw_rows, int lw_cols,
        const val& pt_data, int pt_rows, int pt_cols,
        int num_dims) {
    arma::mat pt = js_to_mat(pt_data, pt_rows, pt_cols);
    if (num_dims <= 0) num_dims = static_cast<int>(pt.n_cols);
    return to_js(qe::directed_node_positions(
        js_to_mat(lw_data, lw_rows, lw_cols),
        pt,
        num_dims, /*combine_pairs=*/true));
}

// ── Rotation ──────────────────────────────────────────────────────────────────

// ena_svd(data, rows, cols)
// → { rotation: matObj, eigenvalues: Float64Array, column_names: string[] }
static val ena_svd(const val& data, int rows, int cols) {
    return to_js(qe::ena_svd(js_to_mat(data, rows, cols)));
}

// deflate(data, rows, cols, axis_data)
// → { data, rows, cols }
static val deflate(const val& data, int rows, int cols, const val& axis_data) {
    std::vector<double> av = vecFromJSArray<double>(axis_data);
    arma::vec axis(av.data(), av.size());
    return mat_to_js(qe::deflate(js_to_mat(data, rows, cols), axis));
}

// orthogonal_svd(data, rows, cols, weights_data, w_rows, w_cols, named_labels)
// → { rotation, eigenvalues, column_names }
static val orthogonal_svd(const val& data, int rows, int cols,
                           const val& weights_data, int w_rows, int w_cols,
                           const val& named_labels_val) {
    std::vector<std::string> labels = vecFromJSArray<std::string>(named_labels_val);
    return to_js(qe::orthogonal_svd(
        js_to_mat(data, rows, cols),
        js_to_mat(weights_data, w_rows, w_cols),
        labels));
}

// complete_rotation(data, rows, cols, named_axes_data, ax_rows, ax_cols, named_labels)
// → { rotation, eigenvalues, column_names }
static val complete_rotation(const val& data, int rows, int cols,
                              const val& axes_data, int ax_rows, int ax_cols,
                              const val& named_labels_val) {
    std::vector<std::string> labels = vecFromJSArray<std::string>(named_labels_val);
    return to_js(qe::complete_rotation(
        js_to_mat(data, rows, cols),
        js_to_mat(axes_data, ax_rows, ax_cols),
        labels));
}

// means_rotation(data, rows, cols, group_pairs)
// group_pairs: Array of { a: Int32Array, b: Int32Array }  (0-based row indices)
// → { rotation, eigenvalues, column_names }
static val means_rotation(const val& data, int rows, int cols,
                           const val& group_pairs_js) {
    int n_pairs = group_pairs_js["length"].as<int>();
    std::vector<qe::GroupPair> pairs;
    pairs.reserve(n_pairs);
    for (int i = 0; i < n_pairs; ++i) {
        val pair = group_pairs_js[i];
        std::vector<int> av = vecFromJSArray<int>(pair["a"]);
        std::vector<int> bv = vecFromJSArray<int>(pair["b"]);
        arma::uvec a(av.size()), b(bv.size());
        for (size_t j = 0; j < av.size(); ++j) a(j) = static_cast<arma::uword>(av[j]);
        for (size_t j = 0; j < bv.size(); ++j) b(j) = static_cast<arma::uword>(bv[j]);
        pairs.push_back({a, b});
    }
    return to_js(qe::means_rotation(js_to_mat(data, rows, cols), pairs));
}

// generalized_means_rotation(...)
// All index arrays (x1_cols, x_subset, y1_cols) are Int32Array of 0-based indices.
// Pass a zero-length Int32Array for x_subset to use all rows.
// Pass empty Float64Array / Int32Array for ignored y params when has_y=false.
// → { rotation, eigenvalues, column_names }
static val generalized_means_rotation(
    const val& V_data,  int V_rows,  int V_cols,
    const val& xm_data, int xm_rows, int xm_cols,
    const val& x_target_data,
    const val& x1_cols_data,
    bool x_categorical, int x_n_groups,
    const val& x_subset_data,
    bool has_y,
    const val& ym_data, int ym_rows, int ym_cols,
    const val& y_target_data,
    const val& y1_cols_data,
    bool y_categorical, int y_n_groups,
    int n_lambda, int k_folds, double lasso_eps
) {
    auto js_to_uvec = [](const val& v) {
        std::vector<int> iv = vecFromJSArray<int>(v);
        arma::uvec out(iv.size());
        for (size_t i = 0; i < iv.size(); ++i)
            out(i) = static_cast<arma::uword>(iv[i]);
        return out;
    };
    auto js_to_arma_vec = [](const val& v) {
        std::vector<double> dv = vecFromJSArray<double>(v);
        return arma::vec(dv.data(), dv.size());
    };

    qe::GeneralizedRotationParams p;
    p.x_model_matrix = js_to_mat(xm_data, xm_rows, xm_cols);
    p.x_target       = js_to_arma_vec(x_target_data);
    p.x1_cols        = js_to_uvec(x1_cols_data);
    p.x_categorical  = x_categorical;
    p.x_n_groups     = static_cast<arma::uword>(x_n_groups);
    p.x_subset       = js_to_uvec(x_subset_data);  // empty → use all rows
    p.has_y          = has_y;
    p.y_model_matrix = js_to_mat(ym_data, ym_rows, ym_cols);
    p.y_target       = js_to_arma_vec(y_target_data);
    p.y1_cols        = js_to_uvec(y1_cols_data);
    p.y_categorical  = y_categorical;
    p.y_n_groups     = static_cast<arma::uword>(y_n_groups);
    p.n_lambda       = n_lambda;
    p.k_folds        = k_folds;
    p.lasso_eps      = lasso_eps;

    return to_js(
        qe::generalized_means_rotation(js_to_mat(V_data, V_rows, V_cols), p));
}

// CCD window-size estimation.
// codes_data: full code matrix (n_rows × n_codes, row-major, flat).
// group_sizes: number of rows in each conversation subset.
// row_indices: 0-based row indices into the code matrix, concatenated in
//              conversation order (length == sum(group_sizes)); this lets the
//              caller pass non-contiguous conversations (cf. parseData's
//              convoGroups) without pre-copying subsets.
// Returns { window_size, peak_lag, lag, frob, frob_sq_unbiased,
//           frob_unbiased_signed, total_weight }.
static val ccd_window(
    const val& codes_data, int n_rows, int n_codes,
    const val& group_sizes_val, const val& row_indices_val,
    int max_window, int min_overlap
) {
    arma::mat codes = js_to_mat(codes_data, n_rows, n_codes);
    std::vector<int> group_sizes = vecFromJSArray<int>(group_sizes_val);
    std::vector<int> row_indices = vecFromJSArray<int>(row_indices_val);

    std::vector<arma::mat> conversations;
    conversations.reserve(group_sizes.size());
    std::size_t cursor = 0;
    for (int sz : group_sizes) {
        arma::uvec rows(sz);
        for (int i = 0; i < sz; ++i) rows[i] = static_cast<arma::uword>(row_indices[cursor++]);
        conversations.push_back(codes.rows(rows));
    }

    return to_js(qe::ccd_window(conversations, max_window, min_overlap));
}

// ── Embind registrations ──────────────────────────────────────────────────────

EMSCRIPTEN_BINDINGS(libena) {
    // Modeling
    function("ena_correlation",                       &ena_correlation);
    function("node_positions",                        &node_positions);
    function("directed_node_positions",               &directed_node_positions);
    function("directed_node_positions_combine_pairs", &directed_node_positions_combine_pairs);

    // Rotation
    function("ena_svd",                               &ena_svd);
    function("deflate",                               &deflate);
    function("orthogonal_svd",                        &orthogonal_svd);
    function("complete_rotation",                     &complete_rotation);
    function("means_rotation",                        &means_rotation);
    function("generalized_means_rotation",            &generalized_means_rotation);

    // CCD window-size estimation
    function("ccd_window",                            &ccd_window);
}
