# Moved from libqe with libena (the ENA C++ layer) in libqe's phase 4a split.
# NaN/Inf guards in the libena wrappers (src/libena_rcpp.cpp).

set.seed(42)
clean_adj    <- matrix(runif(30), nrow = 5, ncol = 6)
clean_points <- matrix(runif(10), nrow = 5, ncol = 2)

nan_adj    <- clean_adj;    nan_adj[1, 1]    <- NaN
nan_points <- clean_points; nan_points[2, 1] <- NaN
inf_points <- clean_points; inf_points[3, 2] <- Inf

# ── node_positions

test_that("node_positions errors on NaN in adj_mats", {
  expect_error(node_positions(nan_adj, clean_points, 2L),
               regexp = "NaN or Inf")
})

test_that("node_positions errors on Inf in points", {
  expect_error(node_positions(clean_adj, inf_points, 2L),
               regexp = "NaN or Inf")
})

test_that("node_positions succeeds on clean inputs", {
  r <- node_positions(clean_adj, clean_points, 2L)
  expect_equal(ncol(r$nodes), 2L)
  expect_true(all(is.finite(r$nodes)))
})

# ── directed_node_positions

test_that("directed_node_positions errors on NaN in line_weights", {
  lw <- matrix(runif(20), nrow = 5, ncol = 4)
  lw[1, 1] <- NaN
  expect_error(directed_node_positions_c(lw, clean_points, 2L),
               regexp = "NaN or Inf")
})

test_that("directed_node_positions errors on Inf in points", {
  lw <- matrix(runif(20), nrow = 5, ncol = 4)
  expect_error(directed_node_positions_c(lw, inf_points, 2L),
               regexp = "NaN or Inf")
})

# ── ena_svd

test_that("ena_svd errors on NaN input", {
  expect_error(ena_svd(nan_points), regexp = "NaN or Inf")
})

test_that("ena_svd errors on Inf input", {
  expect_error(ena_svd(inf_points), regexp = "NaN or Inf")
})

test_that("ena_svd succeeds on clean input", {
  r <- ena_svd(clean_points)
  expect_equal(ncol(r$rotation), 2L)
  expect_true(all(is.finite(r$rotation)))
})
