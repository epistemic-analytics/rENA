context("ena.rotate.by.generalized: orthonormal on masked models")

codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
           "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")

gmr_set <- function(acc) {
  set.seed(1)
  ena.make.set(acc, rotation.by = ena.rotate.by.generalized,
               rotation.params = list(x_var = "Condition",
                                      select_2_groups = c("FirstGame", "SecondGame")))
}

test_that("a masked (all-zero) connection keeps the GMR rotation orthonormal", {
  # The zero column makes the data rank-deficient; before libqe 0.1.6 one of
  # the SVD axes after GMR1 nearly duplicated it (|off-diagonal| 0.991) and the
  # variance shares were wrong (GMR1 23.7% instead of 29.9%).
  data(RS.data)
  acc <- ena.accumulate.data(units = RS.data[, c("Condition", "UserName")],
                             conversation = RS.data[, c("Condition", "GroupName")],
                             codes = RS.data[, codes], window.size.back = 4)
  acc$connection.counts[["Data & Technical.Constraints"]] <-
    as.ena.co.occurrence(rep(0, nrow(acc$connection.counts)))
  set <- gmr_set(acc)

  R <- as.matrix(set$rotation.matrix)
  expect_equal(unname(crossprod(R)), diag(ncol(R)), tolerance = 1e-10)

  # The variance shares are each dimension's share of the total variance.
  pts <- as.matrix(set$points)
  total <- sum(apply(as.matrix(set$model$points.for.projection), 2, var))
  expect_equal(unname(set$model$variance[1:4]),
               unname(apply(pts, 2, var)[1:4] / total), tolerance = 1e-10)
})
