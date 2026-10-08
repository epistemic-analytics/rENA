# Moved from libqe with libena (the ENA C++ layer) in libqe's phase 4a split.
# Node positions and ena_correlation (the libena half of libqe's test-modeling.R).

test_that("lws_lsq_positions: output dimensions are correct", {
    set.seed(30)
    n_units <- 5; n_codes <- 4; n_dims <- 2
    lw  <- matrix(runif(n_units * choose(n_codes, 2)), nrow = n_units)
    pts <- matrix(runif(n_units * n_dims), nrow = n_units)
    out <- node_positions(lw, pts, n_dims)
    expect_equal(nrow(out$nodes),     n_codes)
    expect_equal(ncol(out$nodes),     n_dims)
    expect_equal(nrow(out$centroids), n_units)
    expect_equal(ncol(out$centroids), n_dims)
})

test_that("lws_lsq_positions: centroids are consistent with nodes and weights", {
    # centroids = weights %*% t(nodes), transposed; verify numerically
    set.seed(31)
    lw  <- matrix(abs(rnorm(6 * 3)), nrow = 6)
    pts <- matrix(rnorm(6 * 2), nrow = 6)
    out <- node_positions(lw, pts, 2L)
    reconstructed <- out$weights %*% out$nodes
    expect_equal(reconstructed, out$centroids, tolerance = 1e-6)
})

test_that("directed_node_positions: output dimensions are correct", {
    set.seed(32)
    n_codes <- 3; n_units <- 4; n_dims <- 2
    lw  <- matrix(runif(n_units * n_codes^2), nrow = n_units)
    pts <- matrix(runif(n_units * n_dims), nrow = n_units)
    out <- directed_node_positions_c(lw, pts, n_dims)
    expect_equal(nrow(out$nodes), n_codes)
    expect_equal(ncol(out$nodes), n_dims)
    expect_equal(nrow(out$centroids), n_units)
})

test_that("directed_node_positions_ground_response: requires even n_units", {
    set.seed(33)
    n_codes <- 3; n_units <- 6; n_dims <- 2
    lw  <- matrix(runif(n_units * n_codes^2), nrow = n_units)
    pts <- matrix(runif(n_units * n_dims), nrow = n_units)
    out <- directed_node_positions_combine_pairs(lw, pts, n_dims)
    # centroids are computed over all n_units rows
    expect_equal(nrow(out$centroids), n_units)
    expect_equal(nrow(out$nodes),     n_codes)
})

test_that("ena_correlation: returns matrix of correct shape", {
    set.seed(34)
    pts <- matrix(runif(10 * 2), nrow = 10)
    cts <- matrix(runif(10 * 2), nrow = 10)
    out <- ena_correlation_c(pts, cts, 0.95)
    expect_equal(dim(out), c(2L, 3L))
})

test_that("ena_correlation: r is in [-1, 1] and CI brackets r", {
    set.seed(35)
    pts <- matrix(runif(20 * 2), nrow = 20)
    cts <- matrix(runif(20 * 2), nrow = 20)
    out <- ena_correlation_c(pts, cts, 0.95)
    for (i in 1:2) {
        r <- out[i, 1]; lo <- out[i, 2]; hi <- out[i, 3]
        expect_gte(r,  -1); expect_lte(r,  1)
        expect_lte(lo,  r); expect_gte(hi, r)
    }
})

test_that("ena_correlation: perfectly correlated points give r == 1", {
    pts <- matrix(1:20, nrow = 10)
    cts <- pts * 2                   # identical direction → r = 1
    out <- ena_correlation_c(pts, cts, 0.95)
    expect_equal(out[1, 1], 1, tolerance = 1e-8)
})
