context("skip_sphere_norm(): model without sphere normalization")


codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
           "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
units <- c("Condition", "UserName")
horizon <- c("Condition", "GroupName")

test_that("skip_sphere_norm() scales by the longest network, as fun_skip_sphere_norm", {
  data(RS.data)
  acc <- accumulate(RS.data, units, codes, horizon, default_window = 4)
  lw <- as.matrix(skip_sphere_norm(acc)$line.weights)
  cc <- as.matrix(acc$connection.counts)

  expect_equal(unname(lw), unname(fun_skip_sphere_norm(cc)))
  expect_equal(max(sqrt(rowSums(lw^2))), 1)
  # relative magnitudes are kept: one scale factor for every unit
  ratio <- lw[cc > 0] / cc[cc > 0]
  expect_equal(min(ratio), max(ratio))
  expect_equal(unname(skip_sphere_norm(cc)), unname(fun_skip_sphere_norm(cc)))
})

test_that("model(normalize = skip_sphere_norm) builds ordered models without sphere norm", {
  data(RS.data)
  acc <- accumulate(RS.data, units, codes, horizon, default_window = 4, ordered = TRUE)
  on  <- model(acc)
  off <- model(acc, normalize = skip_sphere_norm)

  expect_equal(unname(as.matrix(off$line.weights)),
               unname(fun_skip_sphere_norm(as.matrix(acc$connection.counts))))
  expect_false(isTRUE(all.equal(as.matrix(on$points), as.matrix(off$points))))
})
