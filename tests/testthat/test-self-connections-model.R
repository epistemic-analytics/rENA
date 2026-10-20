# Unordered models with self-connections in the line weights
# (accumulate(self_connections = TRUE)): the model keeps the adjacency key and
# places nodes by it, each self-connection counted self_weight times.

sc_codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
              "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
sc_set <- function(..., self_weight = 2) suppressWarnings(
  RS.data |> accumulate(c("Condition", "UserName"), sc_codes, c("Condition", "GroupName"),
                        default_window = 4, ...) |> model(self_weight = self_weight)
)
# Independent R version of the rule: pairs to both codes, self `sw` times, L1, least squares.
ref_nodes <- function(set, sw) {
  lw <- as.matrix(set$line.weights); key <- as.matrix(set$rotation$adjacency.key)
  w <- matrix(0, nrow(lw), length(sc_codes))
  for (k in seq_len(ncol(lw))) {
    a <- match(key[1, k], sc_codes); b <- match(key[2, k], sc_codes)
    if (a != b) { w[, a] <- w[, a] + lw[, k]; w[, b] <- w[, b] + lw[, k] }
    else w[, a] <- w[, a] + sw * lw[, k]
  }
  s <- rowSums(abs(w)); s[s < 1e-4] <- 1e-4; w <- w / s
  pts <- as.matrix(set$points)
  list(nodes = solve(crossprod(w), crossprod(w, pts)), w = w)
}

test_that("self_connections = TRUE: self columns in the line weights, key kept by model()", {
  set <- sc_set(self_connections = TRUE)
  expect_equal(ncol(as.matrix(set$line.weights)), 21L)              # 15 pairs + 6 self
  key <- as.matrix(set$rotation$adjacency.key)
  expect_equal(ncol(key), 21L)
  expect_equal(sum(key[1, ] == key[2, ]), 6L)
  expect_equal(colnames(as.matrix(set$line.weights))[1:3],
               c("Data & Data", "Data & Technical.Constraints", "Technical.Constraints & Technical.Constraints"))
  expect_false(is.null(set$rotation$centervec))
  expect_equal(nrow(as.matrix(set$rotation.matrix)), 21L)
})

test_that("nodes follow the key-driven rule (self x2), points unchanged by self_weight", {
  two <- sc_set(self_connections = TRUE)
  one <- sc_set(self_connections = TRUE, self_weight = 1)
  expect_equal(unname(as.matrix(two$rotation$nodes)), unname(ref_nodes(two, 2)$nodes), tolerance = 1e-9)
  expect_equal(unname(as.matrix(one$rotation$nodes)), unname(ref_nodes(one, 1)$nodes), tolerance = 1e-9)
  expect_equal(as.matrix(one$points), as.matrix(two$points))
  expect_gt(max(abs(as.matrix(one$rotation$nodes) - as.matrix(two$rotation$nodes))), 1e-6)
  expect_equal(two$rotation$self.weight, 2)
})

test_that("centroids and the unit-circle move use the same weighting", {
  set <- sc_set(self_connections = TRUE)
  w <- ref_nodes(set, 2)$w
  expect_equal(unname(as.matrix(set$model$centroids)), unname(w %*% as.matrix(set$rotation$nodes)),
               tolerance = 1e-9)
  moved <- move_nodes_to_unit_circle_with_equal_space(set)
  expect_equal(unname(as.matrix(moved$model$centroids)), unname(w %*% as.matrix(moved$rotation$nodes)),
               tolerance = 1e-9)
})

test_that("self columns change the space; without them the model is unchanged", {
  with_self <- sc_set(self_connections = TRUE)
  plain <- sc_set()
  expect_equal(ncol(as.matrix(plain$line.weights)), 15L)
  expect_false(isTRUE(all.equal(as.matrix(with_self$points)[, 1:2], as.matrix(plain$points)[, 1:2])))
  ref <- lws_lsq_positions(as.matrix(plain$line.weights), as.matrix(plain$points), ncol(as.matrix(plain$points)))
  expect_equal(unname(as.matrix(plain$rotation$nodes)), unname(ref$nodes), tolerance = 1e-10)
})

test_that("ordered sets ignore self_connections (they always carry the diagonal)", {
  o1 <- sc_set(ordered = TRUE, self_connections = TRUE)
  o0 <- sc_set(ordered = TRUE)
  expect_equal(as.matrix(o1$rotation$nodes), as.matrix(o0$rotation$nodes))
})
