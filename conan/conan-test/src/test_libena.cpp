// Conan install-verification test: one function from each libena header, to
// confirm the headers (and libqe's, which they include) compile and link.
#include <armadillo>
#include <libena/libena.hpp>
#include <cassert>
#include <cmath>
#include <vector>

int main() {
    arma::mat pts = {{1, 0, 0, 1}, {0, 1, 1, 0}, {2, 1, 1, 2}, {1, 2, 2, 1}};

    // ── rotation ─────────────────────────────────────────────────────────────
    qe::RotationResult svd = qe::ena_svd(pts);
    assert(svd.rotation.n_rows == 4 && svd.rotation.n_cols == 4);
    assert(svd.column_names[0] == "SVD1");

    std::vector<qe::GroupPair> pairs = {{arma::uvec{0, 1}, arma::uvec{2, 3}}};
    qe::RotationResult mr = qe::means_rotation(pts, pairs);
    assert(mr.column_names[0] == "MR1");

    // ── positions ────────────────────────────────────────────────────────────
    arma::mat lw = arma::abs(arma::mat(4, 6, arma::fill::randn));   // 4 codes
    qe::NodePositions np = qe::node_positions(lw, pts.cols(0, 1), 2);
    assert(np.nodes.n_rows == 4 && np.nodes.n_cols == 2);

    // ── ccd ──────────────────────────────────────────────────────────────────
    std::vector<arma::mat> convos = {arma::mat(30, 3, arma::fill::randu)};
    qe::CCDResult ccd = qe::ccd_window(convos, 10, 5);
    assert(ccd.window_size >= 1 && ccd.lag.n_elem == 11);

    return 0;
}
