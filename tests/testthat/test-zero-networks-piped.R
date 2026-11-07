## The piped model() follows ena.make.set(center.align.to.origin = TRUE), the
## webtool's rule, when some units have no connections: those units sit at the
## origin, do not enter the centering, rotation or node fit, and have zero
## centroids. Checked against the legacy path on the same data.

data(RS.data)
codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
           "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
units <- c("UserName", "Condition", "GroupName")
conv  <- c("Condition", "GroupName")

num <- function(x) unname(as.matrix(x))
same_up_to_sign <- function(a, b, dims, tolerance = 1e-10) {
  for (d in dims) {
    flip <- if (sum(a[, d] * b[, d]) < 0) -1 else 1
    expect_equal(flip * a[, d], b[, d], tolerance = tolerance, label = paste("dim", d))
  }
}

# Units that include GroupName give two empty networks on RS.data at window 4.
legacy <- suppressWarnings(ena.make.set(ena.accumulate.data(
  units = RS.data[, units], conversation = RS.data[, conv], codes = RS.data[, codes],
  window.size.back = 4)))
accum <- suppressWarnings(accumulate(RS.data, units, codes, conv, default_window = 4))
piped <- model(accum, rotate_fun = ena.rotate.by.svd)

empty <- rowSums(num(legacy$line.weights)) == 0
ord   <- match(as.character(legacy$points$ENA_UNIT), as.character(piped$points$ENA_UNIT))

test_that("the data has empty networks to test with", {
  expect_equal(sum(empty), 2)
  expect_false(any(is.na(ord)))
})

test_that("empty units sit at the origin with zero centroids", {
  expect_true(all(num(piped$points)[ord, ][empty, ] == 0))
  expect_true(all(num(piped$model$centroids)[ord, ][empty, ] == 0))
})

test_that("piped points, nodes and centroids equal the legacy set", {
  same_up_to_sign(num(piped$points)[ord, ], num(legacy$points), 1:6)
  same_up_to_sign(num(piped$rotation$nodes), num(legacy$rotation$nodes), 1:6)
  same_up_to_sign(num(piped$model$centroids)[ord, ], num(legacy$model$centroids), 1:6)
  expect_equal(piped$rotation$eigenvalues[1:6], legacy$rotation$eigenvalues[1:6], tolerance = 1e-10)
})

test_that("the mean centroid of the fitted units is at the origin, as in the legacy set", {
  expect_equal(unname(colMeans(num(piped$model$centroids)[ord, ][!empty, 1:2])), c(0, 0), tolerance = 1e-10)
})

test_that("exclude_zero_networks = FALSE reproduces center.align.to.origin = FALSE", {
  legacy_all <- suppressWarnings(ena.make.set(ena.accumulate.data(
    units = RS.data[, units], conversation = RS.data[, conv], codes = RS.data[, codes],
    window.size.back = 4), center.align.to.origin = FALSE))
  piped_all <- model(accum, rotate_fun = ena.rotate.by.svd, exclude_zero_networks = FALSE)
  same_up_to_sign(num(piped_all$points)[ord, ], num(legacy_all$points), 1:6)
  same_up_to_sign(num(piped_all$rotation$nodes), num(legacy_all$rotation$nodes), 1:6)
})

test_that("ordered sets: empty units at the origin, nodes fit on the others", {
  accum_ord <- suppressWarnings(accumulate(RS.data, units, codes, conv, default_window = 4, ordered = TRUE))
  m <- model(accum_ord, rotate_fun = ena.rotate.by.svd)
  empty_ord <- rowSums(num(m$line.weights)) == 0
  expect_equal(sum(empty_ord), 1)
  expect_true(all(num(m$points)[empty_ord, ] == 0))
  expect_true(all(num(m$model$centroids)[empty_ord, ] == 0))

  # dropping the empty unit beforehand gives the same nodes and the same points for the rest
  keep <- !empty_ord
  acc2 <- accum_ord
  acc2$connection.counts <- accum_ord$connection.counts[keep, ]
  acc2$meta.data <- accum_ord$meta.data[keep, ]
  m2 <- model(acc2, rotate_fun = ena.rotate.by.svd)
  same_up_to_sign(num(m$points)[keep, ], num(m2$points), 1:6)
  same_up_to_sign(num(m$rotation$nodes), num(m2$rotation$nodes), 1:6)
})

test_that("with no empty units nothing changes", {
  acc_clean <- suppressWarnings(accumulate(RS.data, c("Condition", "UserName"), codes, conv, default_window = 4))
  a <- model(acc_clean, rotate_fun = ena.rotate.by.svd)
  b <- model(acc_clean, rotate_fun = ena.rotate.by.svd, exclude_zero_networks = FALSE)
  expect_equal(num(a$points), num(b$points), tolerance = 1e-12)
  expect_equal(num(a$rotation$nodes), num(b$rotation$nodes), tolerance = 1e-12)
})
