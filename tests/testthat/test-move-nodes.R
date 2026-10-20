# move_nodes_to_unit_circle() / move_nodes_to_unit_circle_with_equal_space()
# run libena's C++ (unit_circle_nodes + node_centroids). The parity tests
# compare them with the R implementations they replaced, kept verbatim in
# helper-move-nodes-reference.R as ref_move_nodes_to_unit_circle*().

rs_codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
              "Client.and.Consultant.Requests", "Design.Reasoning",
              "Collaboration")
rs_units <- c("Condition", "UserName")
rs_horizon <- c("Condition", "GroupName")

rs_set <- function(..., self_weight = 2) {
  suppressWarnings(
    rENA::RS.data |> accumulate(rs_units, rs_codes, rs_horizon, ...) |> model(self_weight = self_weight)
  )
}

# A set whose nodes on dims `dims` are replaced by the columns of `xy`.
with_nodes <- function(set, xy, dims = colnames(as.matrix(set$rotation$nodes))[1:2]) {
  set$rotation$nodes <- data.table::copy(set$rotation$nodes)
  for (k in 1:2) {
    v <- set$rotation$nodes[[dims[k]]]
    v[] <- xy[, k]
    data.table::set(set$rotation$nodes, j = dims[k], value = v)
  }
  set
}

# The fit's own node weighting (the weights node_positions /
# directed_node_positions solve with).
fit_weights <- function(set) {
  lw <- as.matrix(set$line.weights)
  pts <- as.matrix(set$points)
  if (is(set, "ena.ordered.set"))
    directed_node_positions_c(lw, pts, ncol(pts))$weights
  else
    node_positions(lw, pts, ncol(pts))$weights
}

# Directed centroids computed in R from the connection names: each directed
# connection's weight to both of its codes (a self-connection's once), rows
# normalised to sum to 1.
# Directed node weights: each connection to both of its codes; a
# self-connection (a & a) `self_weight` times (the set's, 2 = row + column).
directed_centroids <- function(set, nodes, self_weight = set$rotation$self.weight) {
  lw <- as.matrix(set$line.weights)
  codes <- set$rotation$codes
  w <- matrix(0, nrow(lw), length(codes))
  for (cn in colnames(lw)) {
    ab <- match(strsplit(cn, " & ", fixed = TRUE)[[1]], codes)
    if (ab[2] != ab[1]) {
      w[, ab[1]] <- w[, ab[1]] + lw[, cn]
      w[, ab[2]] <- w[, ab[2]] + lw[, cn]
    } else {
      w[, ab[1]] <- w[, ab[1]] + self_weight * lw[, cn]
    }
  }
  rs <- rowSums(w)
  w[rs != 0, ] <- w[rs != 0, ] / rs[rs != 0]
  w %*% nodes
}

expect_parity <- function(set, ...) {
  new_r <- move_nodes_to_unit_circle(set, ...)
  ref_r <- ref_move_nodes_to_unit_circle(set, ...)
  expect_equal(as.matrix(new_r$rotation$nodes), as.matrix(ref_r$rotation$nodes), tolerance = 1e-12)
  expect_equal(as.matrix(new_r$model$centroids), as.matrix(ref_r$model$centroids), tolerance = 1e-12)

  new_e <- move_nodes_to_unit_circle_with_equal_space(set, ...)
  ref_e <- ref_move_nodes_to_unit_circle_with_equal_space(set, ...)
  expect_equal(as.matrix(new_e$rotation$nodes), as.matrix(ref_e$rotation$nodes), tolerance = 1e-12)
  expect_equal(as.matrix(new_e$model$centroids), as.matrix(ref_e$model$centroids), tolerance = 1e-12)
}

# Radius of each node in the plane of dims (names).
plane_lengths <- function(set, dims) {
  n <- as.matrix(set$rotation$nodes)[, dims]
  unname(sqrt(rowSums(n^2)))
}

test_that("unordered set: both modes match the R implementation", {
  set <- rs_set()
  expect_parity(set)
})

test_that("ena.make.set() set: both modes match the R implementation", {
  rs <- rENA::RS.data
  acc <- ena.accumulate.data(rs[, rs_units], rs[, rs_horizon],
                             rs[, rs_codes], window.size.back = 4)
  set <- ena.make.set(acc)
  expect_parity(set)
})

test_that("non-default dimension pairs match the R implementation", {
  set <- rs_set()
  dims <- colnames(as.matrix(set$rotation$nodes))
  expect_parity(set, dims[3], dims[5])
  expect_parity(set, dims[2], dims[1])   # reversed: y is the first dimension
})

test_that("zero-length and tied nodes match the R implementation", {
  set <- rs_set()
  xy <- as.matrix(set$rotation$nodes)[, 1:2]

  zero_first <- xy; zero_first[1, ] <- 0
  expect_parity(with_nodes(set, zero_first))
  zero_mid <- xy; zero_mid[c(2, 5), ] <- 0
  expect_parity(with_nodes(set, zero_mid))

  # Nodes 1, 4 and 5 tie for the longest; the first of them stays fixed.
  tied_max <- xy; tied_max[c(1, 4, 5), ] <- rbind(c(1, 2), c(2, 1), c(-2, -1))
  expect_parity(with_nodes(set, tied_max))
  moved <- move_nodes_to_unit_circle_with_equal_space(with_nodes(set, tied_max))
  expect_equal(unname(as.matrix(moved$rotation$nodes)[1, 1:2]), c(1, 2))

  # Equal x in the upper half-plane keeps the codes' order; y == 0 with
  # x < 0 counts as the upper half-plane.
  tied_x <- xy; tied_x[c(2, 3, 6), ] <- cbind(0.5, c(0.3, 0.1, 0.2))
  expect_parity(with_nodes(set, tied_x))
  on_axis <- xy; on_axis[3, ] <- c(-1, 0)
  expect_parity(with_nodes(set, on_axis))

  single <- xy; single[-2, ] <- 0
  expect_parity(with_nodes(set, single))
})

test_that("a unit with an empty network keeps a zero centroid", {
  set <- rs_set()
  set$line.weights <- data.table::copy(set$line.weights)
  set$connection.counts <- data.table::copy(set$connection.counts)
  for (cn in colnames(as.matrix(set$line.weights))) {
    data.table::set(set$line.weights, i = 3L, j = cn, value = 0)
    data.table::set(set$connection.counts, i = 3L, j = cn, value = 0)
  }
  expect_parity(set)
  moved <- move_nodes_to_unit_circle_with_equal_space(set)
  expect_true(all(as.matrix(moved$model$centroids)[3, ] == 0))
})

test_that("all-zero nodes are left unchanged", {
  # The R implementation's equal-space version failed here.
  set <- with_nodes(rs_set(), matrix(0, 6, 2))
  for (f in list(move_nodes_to_unit_circle, move_nodes_to_unit_circle_with_equal_space)) {
    moved <- f(set)
    expect_equal(as.matrix(moved$rotation$nodes), as.matrix(set$rotation$nodes))
    expect_equal(as.matrix(moved$model$centroids),
                 fit_weights(set) %*% as.matrix(set$rotation$nodes), tolerance = 1e-12)
  }
})

test_that("nodes land on the circle; other dimensions and points are kept", {
  set <- rs_set()
  dims <- colnames(as.matrix(set$rotation$nodes))
  r <- max(plane_lengths(set, dims[1:2]))
  for (f in list(move_nodes_to_unit_circle, move_nodes_to_unit_circle_with_equal_space)) {
    moved <- f(set)
    expect_equal(plane_lengths(moved, dims[1:2]), rep(r, 6), tolerance = 1e-12)
    expect_equal(as.matrix(moved$rotation$nodes)[, -(1:2)],
                 as.matrix(set$rotation$nodes)[, -(1:2)])
    expect_identical(moved$points, set$points)
  }
  # Equal spacing: consecutive angles 2*pi/6 apart.
  moved <- move_nodes_to_unit_circle_with_equal_space(set)
  xy <- as.matrix(moved$rotation$nodes)[, 1:2]
  angles <- sort(atan2(xy[, 2], xy[, 1]) %% (2 * pi))
  expect_equal(diff(angles), rep(2 * pi / 6, 5), tolerance = 1e-12)
})

test_that("the input set is not modified and column classes are kept", {
  set <- rs_set()
  nodes_before <- data.table::copy(set$rotation$nodes)
  centroids_before <- data.table::copy(set$model$centroids)
  moved <- move_nodes_to_unit_circle_with_equal_space(set)
  expect_identical(set$rotation$nodes, nodes_before)
  expect_identical(set$model$centroids, centroids_before)
  expect_identical(class(moved$rotation$nodes), class(set$rotation$nodes))
  expect_identical(class(moved$model$centroids), class(set$model$centroids))
  expect_identical(lapply(moved$rotation$nodes, class), lapply(set$rotation$nodes, class))
  expect_identical(lapply(moved$model$centroids, class), lapply(set$model$centroids, class))
})

test_that("centroids are the fit's node weights times the moved nodes", {
  for (set in list(rs_set(), rs_set(weight_by = "sqrt"))) {
    w <- fit_weights(set)
    # the fit's own centroids, from its own nodes
    expect_equal(w %*% as.matrix(set$rotation$nodes), as.matrix(set$model$centroids),
                 tolerance = 1e-12, check.attributes = FALSE)
    moved <- move_nodes_to_unit_circle_with_equal_space(set)
    expect_equal(as.matrix(moved$model$centroids), w %*% as.matrix(moved$rotation$nodes),
                 tolerance = 1e-12, check.attributes = FALSE)
  }
})

test_that("ordered set: nodes match the R implementation, centroids use directed weights", {
  # A window of 4 makes the directed networks asymmetric, with
  # self-connections.
  set <- rs_set(ordered = TRUE, default_window = 4)
  expect_s3_class(set, "ena.ordered.set")
  expect_equal(directed_centroids(set, as.matrix(set$rotation$nodes)),
               as.matrix(set$model$centroids), tolerance = 1e-12, check.attributes = FALSE)

  moved_r <- move_nodes_to_unit_circle(set)
  moved_e <- move_nodes_to_unit_circle_with_equal_space(set)
  ref_r <- ref_move_nodes_to_unit_circle(set)
  ref_e <- ref_move_nodes_to_unit_circle_with_equal_space(set)
  expect_equal(as.matrix(moved_r$rotation$nodes), as.matrix(ref_r$rotation$nodes), tolerance = 1e-12)
  expect_equal(as.matrix(moved_e$rotation$nodes), as.matrix(ref_e$rotation$nodes), tolerance = 1e-12)

  for (moved in list(moved_r, moved_e)) {
    expect_equal(as.matrix(moved$model$centroids),
                 directed_centroids(set, as.matrix(moved$rotation$nodes)),
                 tolerance = 1e-12, check.attributes = FALSE)
  }
  # The R implementation read only the i < j connections of an ordered set.
  expect_gt(max(abs(as.matrix(moved_e$model$centroids) - as.matrix(ref_e$model$centroids))), 0.01)

  dims <- colnames(as.matrix(set$rotation$nodes))
  moved <- move_nodes_to_unit_circle_with_equal_space(set, dims[3], dims[2])
  ref <- ref_move_nodes_to_unit_circle_with_equal_space(set, dims[3], dims[2])
  expect_equal(as.matrix(moved$rotation$nodes), as.matrix(ref$rotation$nodes), tolerance = 1e-12)
})

test_that("ordered set: self_weight is recorded and drives the centroids", {
  set2 <- rs_set(ordered = TRUE, default_window = 4)
  expect_equal(set2$rotation$self.weight, 2)
  set1 <- rs_set(ordered = TRUE, default_window = 4, self_weight = 1)
  expect_equal(set1$rotation$self.weight, 1)
  # same points, different nodes (self-connections weigh in differently)
  expect_equal(as.matrix(set1$points), as.matrix(set2$points))
  expect_gt(max(abs(as.matrix(set1$rotation$nodes) - as.matrix(set2$rotation$nodes))), 0.01)
  for (s in list(set1, set2)) {
    expect_equal(directed_centroids(s, as.matrix(s$rotation$nodes)), as.matrix(s$model$centroids),
                 tolerance = 1e-12, check.attributes = FALSE)
    moved <- move_nodes_to_unit_circle_with_equal_space(s)
    expect_equal(as.matrix(moved$model$centroids), directed_centroids(s, as.matrix(moved$rotation$nodes)),
                 tolerance = 1e-12, check.attributes = FALSE)
  }
})

test_that("ordered set with symmetric networks matches the R implementation", {
  # Window 1: every directed connection equals its reverse and there are no
  # self-connections, so the R implementation's weights were right.
  expect_parity(rs_set(ordered = TRUE))
})

test_that("bad dimensions and modes are errors", {
  set <- rs_set()
  dims <- colnames(as.matrix(set$rotation$nodes))
  expect_error(move_nodes_to_unit_circle(set, "nope", dims[2]), "Unknown dimension")
  expect_error(move_nodes_to_unit_circle_with_equal_space(set, dims[1], dims[1]), "must differ")

  lw <- as.matrix(set$line.weights)
  nodes <- as.matrix(set$rotation$nodes)
  expect_error(move_nodes_to_unit_circle_c(lw, nodes, 0L, 1L, "spiral", FALSE), "equal")
  expect_error(move_nodes_to_unit_circle_c(lw, nodes, 0L, ncol(nodes), "equal", FALSE), "out of range")
  expect_error(move_nodes_to_unit_circle_c(lw, nodes, 0L, 1L, "equal", TRUE), "columns")
  expect_error(move_nodes_to_unit_circle_c(lw[, -1], nodes, 0L, 1L, "equal", FALSE), "columns")
  nodes[1, 1] <- NaN
  expect_error(move_nodes_to_unit_circle_c(lw, nodes, 0L, 1L, "equal", FALSE), "NaN")
})
