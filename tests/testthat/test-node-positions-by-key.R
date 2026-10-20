# Layout-agnostic node optimization (libena node_weights_by_key) reproduces
# the undirected and directed solvers, and handles self-connection columns.

bk_codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
              "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
# model() does not keep the adjacency key (yet); take it from the accumulation.
bk_set <- function(...) {
  a <- suppressWarnings(RS.data |> accumulate(c("Condition", "UserName"), bk_codes,
                                              c("Condition", "GroupName"), default_window = 4, ...))
  set <- suppressWarnings(model(a))
  set$rotation$adjacency.key <- a$rotation$adjacency.key
  set
}
keyed <- function(set, self_weight = 2) {
  node_positions_by_key(as.matrix(set$line.weights), as.matrix(set$points),
                        ncol(as.matrix(set$points)), set$rotation$adjacency.key,
                        set$rotation$codes, self_weight)
}

test_that("undirected key reproduces the undirected solver", {
  set <- bk_set()
  ref <- lws_lsq_positions(as.matrix(set$line.weights), as.matrix(set$points), ncol(as.matrix(set$points)))
  got <- keyed(set)
  expect_equal(got$weights, ref$weights, tolerance = 1e-12)
  expect_equal(got$nodes, ref$nodes, tolerance = 1e-10)
  expect_equal(got$centroids, ref$centroids, tolerance = 1e-10)
  expect_equal(unname(got$nodes), unname(as.matrix(set$rotation$nodes)), tolerance = 1e-10)
})

test_that("ordered key reproduces directed_node_positions at the same self_weight", {
  set <- bk_set(ordered = TRUE)
  lw <- as.matrix(set$line.weights); pts <- as.matrix(set$points)
  for (sw in c(1, 2)) {
    ref <- directed_node_positions(lw, pts, ncol(pts), self_weight = sw)
    got <- keyed(set, sw)
    expect_equal(got$weights, ref$weights, tolerance = 1e-12, info = paste("self_weight", sw))
    expect_equal(got$nodes, ref$nodes, tolerance = 1e-10, info = paste("self_weight", sw))
  }
})

test_that("undirected with diagonal = ONA weighting on symmetric data", {
  set.seed(3); p <- 5; codes <- LETTERS[1:p]
  E <- array(runif(4 * p * p), c(4, p, p))
  for (u in 1:4) { m <- E[u, , ]; m <- (m + t(m)) / 2; E[u, , ] <- m }
  directed <- t(apply(E, 1, as.vector))                     # column j*p+i = (i -> j)
  folded <- t(apply(E, 1, function(m) libqe::fold_directed_network(as.vector(m), TRUE)))
  dkey <- rbind(rep(codes, times = p), rep(codes, each = p))
  ukey <- matrix(unlist(strsplit(libqe::connection_names(codes, TRUE), " & ")), nrow = 2)
  ft <- function(k) list(match(k[1, ], codes) - 1L, match(k[2, ], codes) - 1L)
  wd <- do.call(node_weights_by_key_c, c(list(directed), ft(dkey), list(p, 2)))
  wu <- do.call(node_weights_by_key_c, c(list(folded), ft(ukey), list(p, 2)))
  expect_equal(wu, wd, tolerance = 1e-12)
})

test_that("all-zero self columns leave the undirected nodes unchanged", {
  set <- bk_set()
  lw <- as.matrix(set$line.weights); pts <- as.matrix(set$points); p <- length(bk_codes)
  dkey <- matrix(unlist(strsplit(libqe::connection_names(bk_codes, TRUE), " & ")), nrow = 2)
  is_self <- dkey[1, ] == dkey[2, ]
  lw_d <- matrix(0, nrow(lw), ncol(dkey)); lw_d[, !is_self] <- lw   # same pairs, self = 0
  got <- node_positions_by_key(lw_d, pts, ncol(pts), dkey, bk_codes)
  expect_equal(unname(got$nodes), unname(as.matrix(set$rotation$nodes)), tolerance = 1e-10)
})

test_that("node_centroids_by_key = weights x nodes; key errors", {
  set <- bk_set(ordered = TRUE)
  fit <- keyed(set)
  expect_equal(node_centroids_by_key(set$line.weights, fit$nodes, set$rotation$adjacency.key,
                                     set$rotation$codes), fit$centroids, tolerance = 1e-12)
  expect_error(node_positions_by_key(set$line.weights, set$points, 2,
                                     set$rotation$adjacency.key, bk_codes[1:5]), "not in")
  expect_error(node_positions_by_key(set$line.weights, set$points, 2,
                                     set$rotation$adjacency.key[, 1:5], set$rotation$codes), "key has")
})
