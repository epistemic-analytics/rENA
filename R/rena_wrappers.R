# Pure-R replacements for functions that were previously compiled C++ exports
# (rENA/src/ena.cpp).  All math now lives in libqe; these wrappers preserve
# existing R-level function names so no call sites in R code need to change.
#
# Public API functions (exported) are marked @export.
# Internal functions (not exported) have no @export tag.

# ── public API ────────────────────────────────────────────────────────────────

#' Merge data frame columns
#'
#' Paste together multiple columns of a data frame or data.table with a
#' separator, used internally to construct unit-ID strings.
#'
#' @param df    A data.frame or data.table
#' @param cols  Character vector of column names to paste together
#' @param sep   Separator string (default "::")
#' @return A character vector of length \code{nrow(df)}
#' @export
merge_columns_c <- function(df, cols, sep = "::") {
  do.call(paste, c(lapply(cols, function(col) df[[col]]), list(sep = sep)))
}

#' Row-wise L2 (Sphere) Normalization
#'
#' Normalizes each row of a numeric data frame or matrix to unit L2 norm.
#'
#' @param dfM A data.frame or matrix
#' @return A numeric matrix with each row normalized to unit L2 length
#' @export
fun_sphere_norm <- function(dfM) {
  libqe::normalize_networks(as.matrix(dfM))
}

#' Row-wise Max-Norm Scaling
#'
#' Scales all rows of a numeric data frame by dividing by the largest row
#' L2 norm.
#'
#' @param dfM A data.frame or matrix
#' @return A numeric matrix scaled by the largest row L2 norm
#' @export
fun_skip_sphere_norm <- function(dfM) {
  libqe::scale_networks(as.matrix(dfM))
}

#' Upper Triangle from Vector (numeric)
#'
#' Compute pairwise products v[j] * v[i] for all j < i.
#'
#' @param v Numeric vector or single-row matrix
#' @return Numeric row vector of pairwise products
#' @export
vector_to_ut <- function(v) {
  libqe::code_connections(as.matrix(v))
}

#' Directed ENA node positions
#'
#' Least-squares node positions for directed ENA.
#'
#' @param line_weights Numeric matrix (units x connections)
#' @param points       Numeric matrix of rotated points (units x dims)
#' @param numDims      Number of dimensions
#' @return List with nodes, centroids, weights, points
#' @export
directed_node_positions <- function(line_weights, points, numDims) {
  libqe::directed_node_positions(line_weights, points, numDims)
}

#' Directed node positions with ground+response combined
#'
#' Directed node positions with paired ground+response rows combined.
#'
#' @param line_weights Numeric matrix (units x connections)
#' @param points       Numeric matrix of rotated points (units x dims)
#' @param numDims      Number of dimensions
#' @return List with nodes, centroids, weights, points
#' @export
directed_node_positions_with_ground_response_added <- function(line_weights,
                                                                points,
                                                                numDims) {
  libqe::directed_node_positions_combine_pairs(line_weights, points, numDims)
}

#' Calculate ENA correlations
#'
#' Pearson correlation with confidence interval between ENA points and
#' centroids.
#'
#' @param points     Numeric matrix (units x dims)
#' @param centroids  Numeric matrix (units x dims)
#' @param conf_level Confidence level (default 0.95)
#' @return Numeric matrix with columns: r, lower CI, upper CI
#' @export
ena_correlation <- function(points, centroids, conf_level = 0.95) {
  libqe::ena_correlation(points, centroids, conf_level)
}

#' Confidence intervals around group mean positions
#'
#' Per-dimension t-based confidence intervals around the column means of a
#' numeric matrix of ENA points.
#'
#' @param points     Numeric matrix (units x dims)
#' @param conf_level Confidence level (default 0.95)
#' @return Numeric matrix (dims x 3): mean, lower CI, upper CI
#' @export
ena_mean_ci <- function(points, conf_level = 0.95) {
  libqe::mean_ci(as.matrix(points), conf_level)
}

#' Outlier (Tukey-fence) intervals for group positions
#'
#' Per-dimension Tukey-fence intervals: Q1 - k*IQR to Q3 + k*IQR.
#'
#' @param points     Numeric matrix (units x dims)
#' @param iqr_factor IQR multiplier (default 1.5)
#' @return Numeric matrix (dims x 2): lower fence, upper fence
#' @export
ena_outlier_ci <- function(points, iqr_factor = 1.5) {
  libqe::outlier_ci(as.matrix(points), iqr_factor)
}

#' Two-group comparison statistics for ENA points
#'
#' Per-dimension parametric (Welch t-test, Cohen's d) and non-parametric
#' (Wilcoxon rank-sum, rank-biserial r) statistics comparing two groups.
#'
#' @param g1 Numeric matrix of group 1 points (units x dims)
#' @param g2 Numeric matrix of group 2 points (units x dims)
#' @return List with: n1, n2, t, df, pvalue_t, cohens_d, means, sds,
#'   U, pvalue_u, effect_r, medians — each a vector/matrix of length dims
#' @export
ena_group_stats <- function(g1, g2) {
  libqe::group_stats(as.matrix(g1), as.matrix(g2))
}

# ── internal (not exported) ───────────────────────────────────────────────────

# Per-row upper-triangle co-occurrence.
# @param df     A data.frame or matrix of code columns
# @param binary If TRUE, binarise non-zero products
rows_to_co_occurrences <- function(df, binary = TRUE) {
  libqe::row_connections(as.matrix(df), binary)
}

# Stanza-window co-occurrence accumulation.
# @param df            A data.frame or matrix of code columns
# @param windowSize    Rows to look back (default 1; Inf = whole conversation)
# @param windowForward Rows to look forward (default 0)
# @param binary        Binarise co-occurrence counts (default TRUE)
ref_window_df <- function(df, windowSize = 1, windowForward = 0,
                           binary = TRUE) {
  INT_MAX <- .Machine$integer.max
  wb <- if (is.infinite(windowSize)    || windowSize    >= INT_MAX) INT_MAX
        else as.integer(windowSize)
  wf <- if (is.infinite(windowForward) || windowForward >= INT_MAX) INT_MAX
        else as.integer(windowForward)
  data.table::as.data.table(libqe::accumulate_stanza(as.matrix(df), wb, wf, binary))
}

# Rolling backward window sum of code columns.
# @param df         A data.frame or matrix of code columns
# @param windowSize Number of rows to look back (default 0, treated as 1)
# @param binary     Unused; kept for API compatibility
ref_window_lag <- function(df, windowSize = 0, binary = TRUE) {
  libqe::rolling_window_sum(as.matrix(df), windowSize)
}

# Upper-triangle index pairs (0-based, +1 before use as R indices).
# @param len Side length of square code matrix
# @param row -1 = both rows, 0 = row indices, 1 = col indices
triIndices <- function(len, row = -1L) {
  libqe::connection_indices(len, row)
}

# Least-squares node positions (undirected ENA).
# @param adjMats  Numeric matrix of line weights (units x connections)
# @param t        Numeric matrix of rotated points (units x dims)
# @param numDims  Number of dimensions
lws_lsq_positions <- function(adjMats, t, numDims) {
  libqe::node_positions(adjMats, t, numDims)
}

# String upper-triangle pairs: "A" "B" "C" -> "A & B" "A & C" "B & C".
# @param v Character vector of code names
svector_to_ut <- function(v) {
  libqe::connection_names(v)
}

# Center data by subtracting column means.
# @param values Numeric matrix or data.frame
center_data_c <- function(values) {
  libqe::center_points(as.matrix(values))
}
