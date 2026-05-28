## Tests for center(exclude_zero_networks = TRUE) and model() default behaviour
## for ordered sets.

data(RS.data)
RS.data <- data.table::as.data.table(RS.data)

codes        <- c("Data", "Technical.Constraints", "Performance.Parameters",
                  "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
units        <- c("Condition", "UserName")
conversation <- c("Condition", "GroupName")

# Build a normal accumulation and zero out 3 units so we have zero-network rows.
accum <- RS.data |> rENA::accumulate(units, codes, conversation, default_window = 4)

zero_unit_rows  <- c(1L, 3L, 5L)
code_col_names  <- grep(" & ", names(accum$connection.counts), value = TRUE)
accum$connection.counts[zero_unit_rows, (code_col_names) := 0]

# --------------------------------------------------------------------------
# center() — exclude_zero_networks = FALSE (default)
# --------------------------------------------------------------------------

test_that("center(exclude_zero_networks=FALSE) uses all rows for the mean", {
  normed  <- rENA::sphere_norm(accum)
  lw      <- as.matrix(normed$line.weights)

  # Default centering includes zero rows, so global colMeans == colMeans(all rows)
  centered_default <- rENA::center(normed, exclude_zero_networks = FALSE)
  pts              <- as.matrix(centered_default$model$points.for.projection)

  expected_means <- colMeans(lw)
  actual_means   <- colMeans(pts)

  # After subtracting the global mean, the column means of the result are ~0
  expect_true(all(abs(actual_means) < 1e-10))
})

# --------------------------------------------------------------------------
# center() — exclude_zero_networks = TRUE
# --------------------------------------------------------------------------

test_that("center(exclude_zero_networks=TRUE) computes mean from non-zero rows only", {
  normed <- rENA::sphere_norm(accum)
  lw     <- as.matrix(normed$line.weights)

  centered_excl <- rENA::center(normed, exclude_zero_networks = TRUE)
  pts           <- as.matrix(centered_excl$model$points.for.projection)

  nonzero_rows  <- rowSums(lw) != 0
  expected_mean <- colMeans(lw[nonzero_rows, , drop = FALSE])

  # Each row of pts should equal lw[row,] - expected_mean
  for (i in seq_len(nrow(lw))) {
    expect_equal(pts[i, ], lw[i, ] - expected_mean, tolerance = 1e-10)
  }
})

test_that("center(exclude_zero_networks=TRUE) produces different result than FALSE when zeros present", {
  normed <- rENA::sphere_norm(accum)

  pts_default <- as.matrix(rENA::center(normed, exclude_zero_networks = FALSE)$model$points.for.projection)
  pts_excl    <- as.matrix(rENA::center(normed, exclude_zero_networks = TRUE)$model$points.for.projection)

  # The two methods shift by different means, so non-zero-network rows differ
  nonzero_rows <- rowSums(as.matrix(normed$line.weights)) != 0
  expect_false(isTRUE(all.equal(pts_default[nonzero_rows, ], pts_excl[nonzero_rows, ])))
})

test_that("center(exclude_zero_networks=TRUE) produces same result as FALSE when no zeros present", {
  # Build a fresh accumulation with no zeroed units
  accum_clean <- RS.data |> rENA::accumulate(units, codes, conversation, default_window = 4)
  normed      <- rENA::sphere_norm(accum_clean)

  pts_default <- as.matrix(rENA::center(normed, exclude_zero_networks = FALSE)$model$points.for.projection)
  pts_excl    <- as.matrix(rENA::center(normed, exclude_zero_networks = TRUE)$model$points.for.projection)

  expect_equal(pts_default, pts_excl, tolerance = 1e-10)
})

# --------------------------------------------------------------------------
# model() — automatic default for ordered sets
# --------------------------------------------------------------------------

test_that("model() defaults exclude_zero_networks=TRUE for ordered sets", {
  accum_ord <- RS.data |> rENA::accumulate(units, codes, conversation,
                                            ordered = TRUE, default_window = 4)

  # Zero the same units in the ordered accumulation
  code_col_names_ord <- grep(" & ", names(accum_ord$connection.counts), value = TRUE)
  accum_ord$connection.counts[zero_unit_rows, (code_col_names_ord) := 0]

  normed_ord <- rENA::sphere_norm(accum_ord)

  # model() should apply exclude_zero_networks=TRUE automatically
  set_auto <- rENA::model(accum_ord)

  # Manual: center with exclusion explicitly
  set_manual <- accum_ord |>
    rENA::sphere_norm() |>
    rENA::center(exclude_zero_networks = TRUE) |>
    rENA::rotate() |>
    rENA::project() |>
    rENA::optimize()

  expect_equal(
    as.matrix(set_auto$model$points.for.projection),
    as.matrix(set_manual$model$points.for.projection),
    tolerance = 1e-10
  )
})

test_that("model() defaults exclude_zero_networks=FALSE for unordered sets", {
  # For a normal (unordered) set, model() should NOT exclude zeros by default
  set_model <- rENA::model(accum)
  pts       <- as.matrix(set_model$model$points.for.projection)

  # Column means of centered result should be ~0 (global mean subtracted)
  expect_true(all(abs(colMeans(pts)) < 1e-10))
})
