/**
 * @file positions.hpp
 * @brief ENA node-position solvers for undirected and directed networks, the
 *        points-to-centroids correlation (ena_correlation), and the post-fit
 *        unit-circle node move with its centroid recomputation.
 *
 * Split out of the former libqe/modeling.hpp.
 */
#ifndef LIBENA_POSITIONS_HPP
#define LIBENA_POSITIONS_HPP

#include <armadillo>
#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <string>
#include <vector>
#include <libqe/linalg_fallback.hpp>  // qe::linalg::solve_spd
#include <libqe/stats.hpp>            // normal_quantile

namespace qe {

// ---------------------------------------------------------------------------
/// @name Return types
/// @{
// ---------------------------------------------------------------------------

/**
 * @brief Aggregated result returned by every node-position solver.
 *
 * All matrices share the same dimensional conventions:
 * rows index units (or nodes), columns index rotated dimensions.
 */
struct NodePositions {
    arma::mat nodes;      ///< Solved node locations, n_codes × n_dims.
    arma::mat centroids;  ///< Per-unit centroids projected onto the node space, n_units × n_dims.
    arma::mat weights;    ///< Normalised half-edge weight per unit per node, n_units × n_codes.
    arma::mat points;     ///< Input rotated points echoed back unchanged, n_units × n_dims.
};

/**
 * @brief Result of @ref move_nodes_to_unit_circle.
 *
 * Unit points are not part of it: the move never changes them.
 */
struct MovedNodes {
    arma::mat nodes;      ///< Moved node locations, n_codes × n_dims.
    arma::mat centroids;  ///< Centroids recomputed from the moved nodes, n_units × n_dims.
};

/// @}

// ---------------------------------------------------------------------------
/// @name Correlation
/// @{
// ---------------------------------------------------------------------------

/**
 * @brief Pearson correlation with Fisher-z confidence interval between ENA
 *        unit points and their centroids.
 *
 * All unique pairs of units are formed; for each pair the per-dimension
 * difference vectors are computed, then Pearson r is obtained between the
 * @p points differences and the @p centroids differences.  The confidence
 * interval is derived via Fisher's z-transform using the pure-C++
 * `normal_quantile` function so the function works outside R without
 * `Rcpp::qnorm`.
 *
 * @param[in] points      Rotated ENA unit points, n_units × n_dims.
 * @param[in] centroids   Corresponding centroid coordinates, n_units × n_dims.
 * @param[in] conf_level  Confidence level for the interval (default 0.95).
 * @returns An n_dims × 3 matrix whose columns are [r, ci_lower, ci_upper].
 *
 * @note Equivalent to `ena_correlation()` in rENA/ena.cpp.
 */
inline arma::mat ena_correlation(arma::mat points, arma::mat centroids,
                                  double conf_level = 0.95) {
    int n = points.n_rows;
    int n_pairs = (n * (n - 1)) / 2;

    arma::umat idx1(1, n_pairs), idx2(1, n_pairs);
    int col = 0;
    for (int i = 0; i < n; i++)
        for (int j = i + 1; j < n; j++) { idx1[col] = i; idx2[col] = j; col++; }

    arma::mat pts_diff = points.rows(idx1.row(0))    - points.rows(idx2.row(0));
    arma::mat cts_diff = centroids.rows(idx1.row(0)) - centroids.rows(idx2.row(0));
    arma::mat cr       = arma::cor(pts_diff, cts_diff);

    double qq = normal_quantile((1.0 + conf_level) / 2.0);
    arma::mat out(points.n_cols, 3);
    for (arma::uword i = 0; i < points.n_cols; i++) {
        double r     = cr(i, i);
        double z     = std::atanh(r);
        double sigma = 1.0 / std::sqrt(static_cast<double>(n_pairs) - 3.0);
        out(i, 0) = r;
        out(i, 1) = std::tanh(z - sigma * qq);
        out(i, 2) = std::tanh(z + sigma * qq);
    }
    return out;
}

/// @}

// ---------------------------------------------------------------------------
/// @name Node weights
/// @{
// ---------------------------------------------------------------------------

/**
 * @brief Per-unit node weights for undirected ENA.
 *
 * Half of each line weight goes to each of its two codes; each row is then
 * L1-normalised (a row whose L1 norm is below 0.0001 is divided by 0.0001, so
 * an all-zero row stays zero).  This is the weighting @ref node_positions
 * solves with, and the weighting its centroids use.
 *
 * @param[in] line_weights  Upper-triangular adjacency vectors stacked
 *                          row-wise (column order A & B, A & C, B & C, ...),
 *                          n_units × choose(n_codes, 2).
 * @returns n_units × n_codes weights.
 */
inline arma::mat node_weights(const arma::mat& line_weights) {
    int tri_size  = line_weights.n_cols;
    int num_nodes = static_cast<int>(
        std::pow(std::ceil(std::sqrt(static_cast<double>(2 * tri_size))), 2.0)
    ) - (2 * tri_size);
    int row_count = line_weights.n_rows;

    arma::mat weights(row_count, num_nodes, arma::fill::zeros);
    for (int k = 0; k < row_count; k++) {
        arma::rowvec curr = line_weights.row(k);
        int z = 0;
        for (int x = 0; x < num_nodes - 1; x++) {
            for (int y = 0; y <= x; y++) {
                weights(k, x + 1) += 0.5 * curr[z];
                weights(k, y)     += 0.5 * curr[z];
                z++;
            }
        }
    }
    for (int k = 0; k < row_count; k++) {
        double len = arma::accu(arma::abs(weights.row(k)));
        if (len < 0.0001) len = 0.0001;
        weights.row(k) /= len;
    }
    return weights;
}

/**
 * @brief Per-unit node weights for directed (ordered) ENA.
 *
 * Every directed connection's weight goes in full to both of its codes (a
 * self-connection's to its code once); each row is then L1-normalised as in
 * @ref node_weights.  This is the weighting @ref directed_node_positions
 * solves with, and the weighting its centroids use.
 *
 * @param[in] line_weights  Directed adjacency vectors, n_units × (n_codes²).
 * @returns n_units × n_codes weights.
 */
inline arma::mat directed_node_weights(const arma::mat& line_weights) {
    int num_nodes = static_cast<int>(
        std::ceil(std::sqrt(static_cast<double>(line_weights.n_cols)))
    );
    int row_count = line_weights.n_rows;

    arma::mat nw(row_count, num_nodes, arma::fill::zeros);
    for (int k = 0; k < row_count; k++) {
        arma::mat curr = line_weights.row(k);
        int z = 0;
        for (int x = 0; x < num_nodes; x++)
            for (int y = 0; y < num_nodes; y++) {
                nw(k, x) += curr[z];
                if (x != y) nw(k, y) += curr[z];
                z++;
            }
    }
    for (int k = 0; k < row_count; k++) {
        double len = arma::accu(arma::abs(nw.row(k)));
        if (len < 0.0001) len = 0.0001;
        nw.row(k) /= len;
    }
    return nw;
}

/// @}

// ---------------------------------------------------------------------------
/// @name Node-position solvers
/// @{
// ---------------------------------------------------------------------------

/**
 * @brief Multiobjective least-squares node positions for undirected ENA.
 *
 * Half of each adjacency-vector entry (line weight) is distributed to each of
 * its two endpoint nodes, building a per-unit weight matrix
 * (@ref node_weights).  Each row is then L1-normalised.  An overdetermined
 * system is solved per dimension:
 * @code
 *   (W^T W) X = W^T T
 * @endcode
 * where W is the normalised weight matrix and T contains the rotated unit
 * points.
 *
 * @param[in] adj_mats  Upper-triangular adjacency vectors stacked row-wise,
 *                      n_units × tri_size.
 * @param[in] t         Rotated unit points, n_units × n_dims.
 * @param[in] num_dims  Number of dimensions to solve for.
 * @returns A @ref NodePositions struct containing `nodes`, `centroids`,
 *          `weights`, and `points`.
 *
 * @note Equivalent to `lws_lsq_positions()` in rENA/ena.cpp.
 */
inline NodePositions node_positions(arma::mat adj_mats, arma::mat t,
                                        int num_dims) {
    if (!adj_mats.is_finite() || !t.is_finite())
        throw std::invalid_argument("node_positions: input matrices must not contain NaN or Inf");
    arma::mat weights = node_weights(adj_mats);
    int num_nodes = weights.n_cols;

    arma::mat ssX(num_dims, num_nodes, arma::fill::zeros);
    arma::mat ssA = weights.t() * weights;
    for (int i = 0; i < num_dims; i++) {
        arma::mat ssb = weights.t() * t.col(i);
        ssX.row(i) = qe::linalg::solve_spd(ssA, ssb).t();
    }

    NodePositions r;
    r.nodes     = ssX.t();
    r.centroids = (ssX * weights.t()).t();
    r.weights   = weights;
    r.points    = t;
    return r;
}

/**
 * @brief Least-squares node positions for directed (ordered) ENA.
 *
 * Each row of @p line_weights is an n_nodes × n_nodes directed weight matrix
 * stored in row-major order.  The per-unit node weight for node x accumulates
 * the full row weight plus all column weights directed at x from other nodes.
 * Each row is L1-normalised before solving (@ref directed_node_weights).
 *
 * When @p combine_pairs is `false` (the standard directed case) the system:
 * @code
 *   (W^T W) X = W^T P
 * @endcode
 * is solved directly with W = normalised weight matrix and P = @p points.
 *
 * When @p combine_pairs is `true`, adjacent row pairs (ground row k and
 * response row k+1) are summed before solving:
 * @code
 *   W_combined[k/2] = W[k] + W[k+1]
 *   P_combined[k/2] = P[k] + P[k+1]
 * @endcode
 * The system is then solved on the combined matrices, but centroids are
 * projected back using the original (un-combined) weight matrix so that
 * every unit retains its own centroid.
 *
 * @param[in] line_weights  Directed adjacency vectors, n_units × (n_nodes²).
 * @param[in] points        Rotated unit points, n_units × n_dims.
 * @param[in] num_dims      Number of dimensions to solve for.
 * @param[in] combine_pairs If `true`, sum adjacent row pairs before solving
 *                          (ground + response model).  Default `false`.
 * @returns A @ref NodePositions struct containing `nodes`, `centroids`,
 *          `weights`, and `points`.
 *
 * @note Equivalent to `directed_node_positions()` in rENA/ena.cpp when
 *       @p combine_pairs is `false`.
 * @note Equivalent to `directed_node_positions_with_ground_response_added()`
 *       in rENA/ena.cpp when @p combine_pairs is `true`.
 *
 * @warning When @p combine_pairs is `true`, @p line_weights must have an even
 *          number of rows (row_count must be even); odd row counts result in
 *          an out-of-bounds access when forming the combined matrices.
 */
inline NodePositions directed_node_positions(arma::mat line_weights,
                                              arma::mat points, int num_dims,
                                              bool combine_pairs = false) {
    if (!line_weights.is_finite() || !points.is_finite())
        throw std::invalid_argument("directed_node_positions: input matrices must not contain NaN or Inf");
    arma::mat nw = directed_node_weights(line_weights);
    int num_nodes = nw.n_cols;
    int row_count = line_weights.n_rows;

    if (combine_pairs) {
        // Combine paired rows (ground at k, response at k+1)
        arma::mat nw_added(row_count / 2, num_nodes, arma::fill::zeros);
        arma::mat pts_added(row_count / 2, num_dims, arma::fill::zeros);
        for (int k = 0; k < row_count; k += 2) {
            nw_added.row(k / 2)  = nw.row(k)     + nw.row(k + 1);
            pts_added.row(k / 2) = points.row(k) + points.row(k + 1);
        }

        arma::mat ssX(num_dims, num_nodes, arma::fill::zeros);
        arma::mat ssA = nw_added.t() * nw_added;
        for (int i = 0; i < num_dims; i++) {
            arma::mat ssb = nw_added.t() * pts_added.col(i);
            ssX.row(i) = qe::linalg::solve_spd(ssA, ssb).t();
        }

        NodePositions r;
        r.nodes     = ssX.t();
        r.centroids = (ssX * nw.t()).t();
        r.weights   = nw;
        r.points    = points;
        return r;
    }

    arma::mat ssX(num_dims, num_nodes, arma::fill::zeros);
    arma::mat ssA = nw.t() * nw;
    for (int i = 0; i < num_dims; i++) {
        arma::mat ssb = nw.t() * points.col(i);
        ssX.row(i) = qe::linalg::solve_spd(ssA, ssb).t();
    }

    NodePositions r;
    r.nodes     = ssX.t();
    r.centroids = (ssX * nw.t()).t();
    r.weights   = nw;
    r.points    = points;
    return r;
}

/// @}

// ---------------------------------------------------------------------------
/// @name Post-fit node moves
/// @{
// ---------------------------------------------------------------------------

/**
 * @brief How @ref unit_circle_nodes places the nodes on the circle.
 */
enum class UnitCircleMode {
    Equal,   ///< Equally spaced, 2π/n apart, the longest node fixed.
    Radial   ///< Each node pushed out along its own ray.
};

/**
 * @brief Parse a mode name for the bindings: "equal" or "radial".
 *
 * @throws std::invalid_argument for any other name.
 */
inline UnitCircleMode unit_circle_mode(const std::string& name) {
    if (name == "equal")  return UnitCircleMode::Equal;
    if (name == "radial") return UnitCircleMode::Radial;
    throw std::invalid_argument(
        "unit_circle_mode: mode must be \"equal\" or \"radial\", got \"" + name + "\"");
}

/**
 * @brief Move nodes onto a circle in the plane of two dimensions.
 *
 * The circle's radius is the length of the longest node in that plane.
 * Nodes of length zero there are left where they are, and every other
 * dimension is unchanged.
 *
 * - @ref UnitCircleMode::Radial: each node moves out along its own ray.
 * - @ref UnitCircleMode::Equal: the nodes keep their order around the
 *   origin and are spaced 2π/n apart, counter-clockwise, starting from the
 *   longest node, which stays where it is (the first one when lengths tie).
 *   The order is that of rENA's original R implementation: nodes with
 *   y >= 0 by decreasing x, then nodes with y < 0 by increasing x, ties in
 *   their original order.
 *
 * A post-fit transform for display; it does not refit anything.  Use
 * @ref node_centroids to recompute the centroids for the moved nodes.
 *
 * @param[in] nodes  Node positions, n_codes × n_dims.
 * @param[in] dim_x  0-based column of the plane's x axis.
 * @param[in] dim_y  0-based column of the plane's y axis.
 * @param[in] mode   Equal (default) or Radial.
 * @returns A copy of @p nodes with columns @p dim_x and @p dim_y moved.
 *
 * @throws std::invalid_argument if a dimension is out of range, the two are
 *         the same, or @p nodes contains NaN or Inf.
 *
 * @note Equivalent to rENA's move_nodes_to_unit_circle() (Radial) and
 *       move_nodes_to_unit_circle_with_equal_space() (Equal), up to their
 *       centroid step.
 */
inline arma::mat unit_circle_nodes(const arma::mat& nodes, arma::uword dim_x,
                                   arma::uword dim_y,
                                   UnitCircleMode mode = UnitCircleMode::Equal) {
    if (dim_x >= nodes.n_cols || dim_y >= nodes.n_cols)
        throw std::invalid_argument(
            "unit_circle_nodes: dimension index out of range (nodes have " +
            std::to_string(nodes.n_cols) + " columns)");
    if (dim_x == dim_y)
        throw std::invalid_argument("unit_circle_nodes: the two dimensions must differ");
    if (!nodes.is_finite())
        throw std::invalid_argument("unit_circle_nodes: nodes must not contain NaN or Inf");

    arma::mat out = nodes;
    const arma::uword n = nodes.n_rows;
    arma::vec x = nodes.col(dim_x);
    arma::vec y = nodes.col(dim_y);

    std::vector<double> len(n);
    std::vector<arma::uword> non_zero;
    double max_len = 0.0;
    for (arma::uword k = 0; k < n; ++k) {
        len[k] = std::sqrt(x[k] * x[k] + y[k] * y[k]);
        if (len[k] > max_len) max_len = len[k];
        if (len[k] != 0.0) non_zero.push_back(k);
    }
    if (non_zero.empty()) return out;

    if (mode == UnitCircleMode::Radial) {
        for (arma::uword k : non_zero) {
            double scale = max_len / len[k];
            out(k, dim_x) = x[k] * scale;
            out(k, dim_y) = y[k] * scale;
        }
        return out;
    }

    // Order around the origin: upper half-plane (y >= 0) by decreasing x,
    // then lower half-plane by increasing x; stable, as R's order().
    // Deliberate: this is the old R code's order, kept for parity (the
    // user's decision, 2026-10-16), not true angular order. The two differ
    // only when nodes of different lengths cross between x order and angle.
    std::vector<arma::uword> upper, lower;
    for (arma::uword k : non_zero) (y[k] >= 0.0 ? upper : lower).push_back(k);
    std::stable_sort(upper.begin(), upper.end(),
                     [&](arma::uword a, arma::uword b) { return x[a] > x[b]; });
    std::stable_sort(lower.begin(), lower.end(),
                     [&](arma::uword a, arma::uword b) { return x[a] < x[b]; });
    std::vector<arma::uword> sorted(upper);
    sorted.insert(sorted.end(), lower.begin(), lower.end());

    // The longest node (first in node order on a tie) stays put; the others
    // follow it around the circle.
    arma::uword fixed = non_zero.front();
    for (arma::uword k : non_zero)
        if (len[k] == max_len) { fixed = k; break; }
    const std::size_t m = sorted.size();
    const std::size_t first =
        std::find(sorted.begin(), sorted.end(), fixed) - sorted.begin();

    const double x1 = x[fixed], y1 = y[fixed];
    const double step = 2.0 * arma::datum::pi / static_cast<double>(m);
    for (std::size_t i = 0; i < m; ++i) {
        const arma::uword k = sorted[(first + i) % m];
        const double angle = static_cast<double>(i) * step;
        out(k, dim_x) = x1 * std::cos(angle) - y1 * std::sin(angle);
        out(k, dim_y) = x1 * std::sin(angle) + y1 * std::cos(angle);
    }
    return out;
}

/**
 * @brief Unit centroids for a set of node positions.
 *
 * The model's node weights (@ref node_weights, or @ref directed_node_weights
 * when @p directed) times @p nodes: the centroids @ref node_positions and
 * @ref directed_node_positions return, for any nodes.  Given a fit's own
 * nodes it reproduces the fit's centroids; given moved nodes, it gives the
 * centroids that match them.
 *
 * Line weights rather than raw connection counts: the two give the same
 * weights for the default (binary) weight model, since each unit's line
 * weights are its counts scaled, and the line weights are what the fit used
 * for any weight model.
 *
 * @param[in] line_weights  The model's line weights, n_units ×
 *                          choose(n_codes, 2), or n_units × n_codes² when
 *                          @p directed.
 * @param[in] nodes         Node positions, n_codes × n_dims.
 * @param[in] directed      Ordered (directed) networks.  Default `false`.
 * @returns n_units × n_dims centroids.
 *
 * @throws std::invalid_argument if the line weights' column count does not
 *         match the number of nodes, or either input contains NaN or Inf.
 */
inline arma::mat node_centroids(const arma::mat& line_weights,
                                const arma::mat& nodes, bool directed = false) {
    const arma::uword n = nodes.n_rows;
    if (!directed && n < 2)
        throw std::invalid_argument("node_centroids: undirected networks need at least 2 codes");
    const arma::uword expected = directed ? n * n : n * (n - 1) / 2;
    if (line_weights.n_cols != expected)
        throw std::invalid_argument(
            "node_centroids: line_weights has " + std::to_string(line_weights.n_cols) +
            " columns; " + std::to_string(n) + " nodes need " + std::to_string(expected) +
            (directed ? " (n_codes², directed)" : " (choose(n_codes, 2), undirected)"));
    if (!line_weights.is_finite() || !nodes.is_finite())
        throw std::invalid_argument("node_centroids: input matrices must not contain NaN or Inf");

    const arma::mat weights = directed ? directed_node_weights(line_weights)
                                       : node_weights(line_weights);
    return weights * nodes;
}

/**
 * @brief The post-fit unit-circle move of a model: moved nodes and their
 *        centroids.
 *
 * @ref unit_circle_nodes on the model's nodes, then @ref node_centroids for
 * the moved nodes.  Unit points are never changed, so a model keeps its
 * points and takes the returned nodes and centroids.
 *
 * @param[in] line_weights  The model's line weights (see @ref node_centroids).
 * @param[in] nodes         The model's node positions, n_codes × n_dims.
 * @param[in] dim_x         0-based column of the plane's x axis.
 * @param[in] dim_y         0-based column of the plane's y axis.
 * @param[in] mode          Equal (default) or Radial.
 * @param[in] directed      Ordered (directed) networks.  Default `false`.
 * @returns A @ref MovedNodes with the moved nodes and recomputed centroids.
 *
 * @throws std::invalid_argument as @ref unit_circle_nodes and
 *         @ref node_centroids.
 */
inline MovedNodes move_nodes_to_unit_circle(const arma::mat& line_weights,
                                            const arma::mat& nodes,
                                            arma::uword dim_x, arma::uword dim_y,
                                            UnitCircleMode mode = UnitCircleMode::Equal,
                                            bool directed = false) {
    MovedNodes r;
    r.nodes     = unit_circle_nodes(nodes, dim_x, dim_y, mode);
    r.centroids = node_centroids(line_weights, r.nodes, directed);
    return r;
}

/// @}

} // namespace qe

#endif // LIBENA_POSITIONS_HPP
