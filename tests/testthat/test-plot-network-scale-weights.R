suppressMessages(library(rENA, quietly = TRUE, verbose = FALSE))

data(RS.data)
codenames <- c("Data", "Technical.Constraints", "Performance.Parameters",
  "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")

edge_opacities <- function(p) {
  unlist(lapply(p$plot$x$attrs, function(t) t$opacity))
}

test_that("scale.weights keeps saturation/opacity in [0, 1] for all-positive networks", {
  set <- RS.data |>
    accumulate(c("Condition", "UserName"), codenames,
               c("Condition", "GroupName"), default_window = 4) |>
    model()
  g1 <- colMeans(as.matrix(set$line.weights)[set$meta.data$Condition == "FirstGame", ])
  expect_true(all(g1 >= 0))
  expect_lt(max(abs(g1)), 1)

  p <- NULL
  expect_no_error(
    p <- ena.plot(set) |> ena.plot.network(network = g1, scale.weights = TRUE)
  )
  op <- edge_opacities(p)
  expect_true(length(op) > 0)
  expect_true(all(op >= 0 & op <= 1))

  # saturation/opacity under scale.weights match the unscaled mapping
  p0 <- ena.plot(set) |> ena.plot.network(network = g1)
  expect_equal(unname(sort(op)), unname(sort(edge_opacities(p0))))
})
