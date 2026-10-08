// [[Rcpp::depends(RcppArmadillo)]]
// Rcpp wrappers for libena, the ENA layer of the libqe C++ libraries. The
// headers live in inst/include/libena/ (moved from libqe); they build on
// libqe's generic numerics, which come from LinkingTo: libqe.
//
// These functions are internal: rENA's R code calls them, and its exported
// R functions are the API. ena_correlation_c and directed_node_positions_c
// are suffixed because rENA exports R functions with the plain names.
#include <RcppArmadillo.h>
#include <libena/rotation.hpp>
#include <libena/generalized_rotation.hpp>
#include <libena/positions.hpp>
#include <libena/ccd.hpp>

using namespace Rcpp;

// =============================================================================
// Node positions and correlation
// =============================================================================

// Pearson correlation with CI between ENA points and centroids
// @param points  Numeric matrix (units x dims)
// @param centroids Numeric matrix (units x dims)
// @param conf_level Confidence level (default 0.95)
// [[Rcpp::export]]
arma::mat ena_correlation_c(arma::mat points, arma::mat centroids,
                              double conf_level = 0.95) {
    return qe::ena_correlation(points, centroids, conf_level);
}

// Least-squares node positions for undirected ENA
// @param adj_mats Numeric matrix of line weights (units x connections)
// @param t        Numeric matrix of rotated points (units x dims)
// @param num_dims Number of dimensions
// @return List with nodes, centroids, weights, points
// [[Rcpp::export]]
List node_positions(arma::mat adj_mats, arma::mat t, int num_dims) {
    if (!adj_mats.is_finite() || !t.is_finite())
        stop("node_positions: input matrices must not contain NaN or Inf - "
             "filter or impute rows with non-finite values before calling");
    qe::NodePositions r = qe::node_positions(adj_mats, t, num_dims);
    return List::create(
        _("nodes")     = r.nodes,
        _("centroids") = r.centroids,
        _("weights")   = r.weights,
        _("points")    = r.points
    );
}

// Least-squares node positions for directed ENA
// @param line_weights Numeric matrix (units x connections)
// @param points       Numeric matrix of rotated points (units x dims)
// @param num_dims     Number of dimensions
// @return List with nodes, centroids, weights, points
// [[Rcpp::export]]
List directed_node_positions_c(arma::mat line_weights, arma::mat points,
                                 int num_dims) {
    if (!line_weights.is_finite() || !points.is_finite())
        stop("directed_node_positions: input matrices must not contain NaN or Inf - "
             "filter or impute rows with non-finite values before calling");
    qe::NodePositions r = qe::directed_node_positions(line_weights, points, num_dims);
    return List::create(
        _("nodes")     = r.nodes,
        _("centroids") = r.centroids,
        _("weights")   = r.weights,
        _("points")    = r.points
    );
}

// Directed node positions with paired ground+response rows combined
// @param line_weights Numeric matrix (units x connections)
// @param points       Numeric matrix of rotated points (units x dims)
// @param num_dims     Number of dimensions
// @return List with nodes, centroids, weights, points
// [[Rcpp::export]]
List directed_node_positions_combine_pairs(arma::mat line_weights,
                                               arma::mat points,
                                               int num_dims) {
    if (!line_weights.is_finite() || !points.is_finite())
        stop("directed_node_positions_combine_pairs: input matrices must not contain NaN or Inf - "
             "filter or impute rows with non-finite values before calling");
    qe::NodePositions r = qe::directed_node_positions(
        line_weights, points, num_dims, true);
    return List::create(
        _("nodes")     = r.nodes,
        _("centroids") = r.centroids,
        _("weights")   = r.weights,
        _("points")    = r.points
    );
}

// =============================================================================
// Rotation
// =============================================================================

// Pack a RotationResult into the list shape that matches rENA's ENARotationSet
// payload (rotation + eigenvalues + column names). Column names are attached
// to the rotation matrix as dimnames so downstream R code can index by them.
// Eigenvalues are returned as a plain numeric vector (not an Nx1 matrix) to
// match what rENA's `pcaResults$sdev^2` produces.
static List pack_rotation_result(const qe::RotationResult& r) {
    NumericMatrix rotation = wrap(r.rotation);
    CharacterVector col_names(r.column_names.begin(), r.column_names.end());
    rotation.attr("dimnames") = List::create(R_NilValue, col_names);
    NumericVector eigenvalues(r.eigenvalues.begin(), r.eigenvalues.end());
    return List::create(
        _("rotation")     = rotation,
        _("eigenvalues")  = eigenvalues,
        _("column_names") = col_names
    );
}

// SVD rotation (matches prcomp(retx=F, scale=F, center=F, tol=0))
//
// Caller is responsible for centering upstream. Eigenvalues are stored as
// \code{sdev^2} (variance) to match rENA's \code{ena.svd}.
//
// @param points Numeric matrix (n_units x n_dims)
// @return List with \code{rotation} (n_dims x n_dims), \code{eigenvalues}
//   (length n_dims, = sdev^2), and \code{column_names} ("SVD1", "SVD2", ...)
// [[Rcpp::export]]
List ena_svd(arma::mat points) {
    if (!points.is_finite())
        stop("ena_svd: input matrix must not contain NaN or Inf - "
             "filter or impute rows with non-finite values before calling");
    return pack_rotation_result(qe::ena_svd(points));
}

// Project a matrix onto the hyperplane orthogonal to a unit-norm axis
//
// Computes \code{data - (data \%*\% axis) \%*\% t(axis)}. The caller is
// responsible for ensuring \code{axis} is unit-norm.
//
// @param data Numeric matrix (n_units x n_dims)
// @param axis Numeric vector of length n_dims, unit-norm
// @return Numeric matrix of the same shape as \code{data}
// [[Rcpp::export]]
arma::mat deflate(arma::mat data, arma::vec axis) {
    return qe::deflate(data, axis);
}

// Orthogonal SVD — orthonormalize named axes via QR, fill the rest from SVD
//
// Mirrors rENA's \code{orthogonal_svd()} in \code{ena.rotate.by.mean.R}:
// the named axes in the output are the orthonormalized Q columns, not the
// original \code{weights} columns. Use \code{complete_rotation} to keep
// the named axes verbatim.
//
// @param data         Numeric matrix (n_units x n_dims)
// @param weights      Numeric matrix (n_dims x k); columns are the named axes
// @param named_labels Character vector of length k
// @return List with \code{rotation}, \code{eigenvalues}, \code{column_names}
// [[Rcpp::export]]
List orthogonal_svd(arma::mat data,
                        arma::mat weights,
                        std::vector<std::string> named_labels) {
    return pack_rotation_result(qe::orthogonal_svd(data, weights, named_labels));
}

// Complete a rotation — keep named axes verbatim, fill remainder from SVD
//
// Mirrors the tail of \code{ena.rotate.by.generalized}: the named axes
// appear in the output exactly as provided, and the trailing columns come
// from an SVD of the data deflated by all named axes.
// On rank-deficient data (e.g. an all-zero connection column) the trailing
// axes that come from the deflated data's null space are orthogonalised
// against the named axes, so the rotation is orthonormal whenever the named
// axes are.
//
// @param data         Numeric matrix (n_units x n_dims)
// @param named_axes   Numeric matrix (n_dims x k); columns must be unit-norm
// @param named_labels Character vector of length k
// @return List with \code{rotation}, \code{eigenvalues}, \code{column_names}
// [[Rcpp::export]]
List complete_rotation(arma::mat data,
                           arma::mat named_axes,
                           std::vector<std::string> named_labels) {
    return pack_rotation_result(qe::complete_rotation(data, named_axes, named_labels));
}

// Means rotation
//
// For each group pair, computes a normalized mean-difference axis on the
// progressively-deflated data and finishes with \code{orthogonal_svd}.
// The input is column-centered first, matching rENA's
// \code{scale(data, scale=F, center=T)} at the top of \code{ena.rotate.by.mean}.
//
// Each element of \code{group_pairs} is a length-2 list \code{list(a, b)}
// of 0-based row indices into \code{points}.
//
// @param points      Numeric matrix (n_units x n_dims)
// @param group_pairs List of length k; each element is \code{list(a, b)}
//   where \code{a} and \code{b} are 0-based integer index vectors
// @return List with \code{rotation}, \code{eigenvalues}, \code{column_names}
// [[Rcpp::export]]
List means_rotation(arma::mat points, List group_pairs) {
    std::vector<qe::GroupPair> pairs;
    pairs.reserve(group_pairs.size());
    for (R_xlen_t i = 0; i < group_pairs.size(); ++i) {
        List pair = group_pairs[i];
        if (pair.size() != 2) {
            stop("group_pairs[[%d]] must be a length-2 list(a, b)",
                 static_cast<int>(i + 1));
        }
        IntegerVector ra = pair[0];
        IntegerVector rb = pair[1];
        arma::uvec a(ra.size());
        arma::uvec b(rb.size());
        for (R_xlen_t j = 0; j < ra.size(); ++j) {
            a(j) = static_cast<arma::uword>(ra[j]);
        }
        for (R_xlen_t j = 0; j < rb.size(); ++j) {
            b(j) = static_cast<arma::uword>(rb[j]);
        }
        pairs.push_back({a, b});
    }
    return pack_rotation_result(qe::means_rotation(points, pairs));
}

// =============================================================================
// Generalized Means Rotation (GMR)
// =============================================================================

// Generalized Means Rotation
//
// Computes a rotation axis that best represents a target variable's
// contribution to the ENA point space, after controlling for covariates via
// Lasso (coordinate-descent, k-fold CV).  Mirrors
// \code{rENA::ena.rotate.by.generalized()}.
//
// The caller is responsible for building \code{x_model_matrix} (e.g. via
// \code{model.matrix()}) and identifying \code{x1_cols} (0-based indices of
// the target variable's columns, which receive \code{penalty_factor = 0}).
// Categorical targets should be encoded as 0-based integers.
//
// @param V              Numeric matrix (n_units x n_connections) — ENA points.
// @param x_model_matrix Numeric matrix (n_units x p) — model matrix for x axis.
// @param x_target       Numeric vector length n — target variable (raw float
//   for numeric; 0-based integer codes for categorical).
// @param x1_cols        Integer vector of 0-based column indices in
//   \code{x_model_matrix} that belong to the target variable (unpenalized).
// @param x_categorical  Logical — TRUE if target is categorical.
// @param x_n_groups     Integer — number of distinct groups (categorical only).
// @param x_subset       Integer vector of 0-based row indices to subset for
//   the x-axis GMR step (pass \code{integer(0)} to use all rows).
// @param has_y          Logical — TRUE to compute a second GMR axis.
// @param y_model_matrix Numeric matrix (n_units x p) — model matrix for y axis
//   (ignored when \code{has_y = FALSE}).
// @param y_target       Numeric vector — y-axis target (ignored when
//   \code{has_y = FALSE}).
// @param y1_cols        0-based column indices for y target (ignored when
//   \code{has_y = FALSE}).
// @param y_categorical  Logical (ignored when \code{has_y = FALSE}).
// @param y_n_groups     Integer (ignored when \code{has_y = FALSE}).
// @param n_lambda       Length of the Lasso lambda path (default 50).
// @param k_folds        Cross-validation folds for lambda selection (default 5).
// @param lasso_eps      \code{lambda_min = lasso_eps * lambda_max} (default 0.01).
// @return List with \code{rotation}, \code{eigenvalues}, \code{column_names}.
// [[Rcpp::export]]
List generalized_means_rotation(
    arma::mat V,
    arma::mat x_model_matrix,
    arma::vec x_target,
    IntegerVector x1_cols,
    bool x_categorical,
    int  x_n_groups,
    IntegerVector x_subset,
    bool has_y,
    arma::mat y_model_matrix,
    arma::vec y_target,
    IntegerVector y1_cols,
    bool y_categorical,
    int  y_n_groups,
    int  n_lambda  = 50,
    int  k_folds   = 5,
    double lasso_eps = 0.01
) {
    // ── Unpack x1_cols ───────────────────────────────────────────────────────
    arma::uvec x1(x1_cols.size());
    for (R_xlen_t i = 0; i < x1_cols.size(); ++i)
        x1(i) = static_cast<arma::uword>(x1_cols[i]);

    // ── Unpack x_subset (empty IntegerVector → use all rows) ─────────────────
    arma::uvec x_sub;
    if (x_subset.size() > 0) {
        x_sub.set_size(x_subset.size());
        for (R_xlen_t i = 0; i < x_subset.size(); ++i)
            x_sub(i) = static_cast<arma::uword>(x_subset[i]);
    }

    // ── Unpack y1_cols ───────────────────────────────────────────────────────
    arma::uvec y1(y1_cols.size());
    for (R_xlen_t i = 0; i < y1_cols.size(); ++i)
        y1(i) = static_cast<arma::uword>(y1_cols[i]);

    // ── Build params ─────────────────────────────────────────────────────────
    qe::GeneralizedRotationParams p;
    p.x_model_matrix = x_model_matrix;
    p.x_target       = x_target;
    p.x1_cols        = x1;
    p.x_categorical  = x_categorical;
    p.x_n_groups     = static_cast<arma::uword>(x_n_groups);
    p.x_subset       = x_sub;
    p.has_y          = has_y;
    p.y_model_matrix = y_model_matrix;
    p.y_target       = y_target;
    p.y1_cols        = y1;
    p.y_categorical  = y_categorical;
    p.y_n_groups     = static_cast<arma::uword>(y_n_groups);
    p.n_lambda       = n_lambda;
    p.k_folds        = k_folds;
    p.lasso_eps      = lasso_eps;

    return pack_rotation_result(qe::generalized_means_rotation(V, p));
}

// =============================================================================
// CCD window estimation
// =============================================================================

// Cross-covariance decay (CCD) window-size estimation
//
// Estimates the ENA moving-window size from the half-life decay lag of the
// noise-corrected Frobenius norm of pooled conversation cross-covariance
// matrices.
//
// @param conversations A list of numeric code matrices, one per conversation
//   (rows in sequence; all matrices share the same number of columns).
// @param max_window Maximum lag to evaluate (default 20).
// @param min_overlap Minimum overlapping rows (N - lag) required for a
//   conversation to contribute at a given lag (default 10).
//
// @return A list with \code{window_size}, \code{peak_lag}, and the per-lag
//   curves \code{lag}, \code{frob}, \code{frob_sq_unbiased},
//   \code{frob_unbiased_signed}, and \code{total_weight}.
// [[Rcpp::export]]
Rcpp::List ccd_window(
    Rcpp::List conversations,
    int max_window = 20,
    int min_overlap = 10
) {
    std::vector<arma::mat> convos;
    convos.reserve(conversations.size());
    for (R_xlen_t i = 0; i < conversations.size(); ++i) {
        convos.push_back(Rcpp::as<arma::mat>(conversations[i]));
    }

    qe::CCDResult res = qe::ccd_window(convos, max_window, min_overlap);

    return Rcpp::List::create(
        Named("window_size")          = res.window_size,
        Named("peak_lag")             = res.peak_lag,
        Named("lag")                  = res.lag,
        Named("frob")                 = res.frob,
        Named("frob_sq_unbiased")     = res.frob_sq_unbiased,
        Named("frob_unbiased_signed") = res.frob_unbiased_signed,
        Named("total_weight")         = res.total_weight
    );
}
