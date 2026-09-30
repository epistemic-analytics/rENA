context("ena.plot backend switch (qeviz)")

.qe_ready <- function() {
  requireNamespace("qeviz", quietly = TRUE) && utils::packageVersion("qeviz") >= "0.5.0"
}

.backend_set <- function() {
  data(RS.data, package = "rENA", envir = environment())
  codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
             "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
  ena.make.set(ena.accumulate.data(
    units        = RS.data[, c("Condition", "UserName")],
    conversation = RS.data[, c("Condition", "GroupName")],
    codes        = RS.data[, codes],
    window.size.back = 4))
}

test_that("plotly stays the default and is unchanged", {
  p <- ena.plot(.backend_set())
  expect_identical(p$get("backend"), "plotly")
  expect_s3_class(p$plot, "plotly")
  expect_null(p$qe)
})

test_that("backend = 'qeviz' gives a qeviz widget with nothing drawn yet", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  p <- ena.plot(.backend_set(), title = "Empty", backend = "qeviz")
  expect_identical(p$get("backend"), "qeviz")
  expect_s3_class(p$qe, "qe_plot")
  w <- p$plot
  expect_s3_class(w, "htmlwidget")
  expect_s3_class(w, "qeviz")
  expect_match(w$x$graph, 'plot-title="Empty"', fixed = TRUE)
  expect_match(w$x$graph, 'range="network"', fixed = TRUE)
  expect_match(w$x$graph, 'scale-points="false"', fixed = TRUE)
  expect_match(w$x$graph, 'label-font-size="10"', fixed = TRUE)
  expect_match(w$x$graph, 'label-font-family="Arial"', fixed = TRUE)
  expect_false(grepl("<qe-means|<qe-edges|<qe-points|<qe-nodes", w$x$graph))
  expect_match(w$x$graph, "<qe-axes>", fixed = TRUE)
  expect_identical(p$palette, qeviz::qe_palette())
})

test_that("the rENA.plot.backend option selects the backend, plot.ena.set included", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .backend_set()
  old <- options(rENA.plot.backend = "qeviz"); on.exit(options(old))
  expect_identical(ena.plot(set)$get("backend"), "qeviz")
  expect_identical(plot(set)$get("backend"), "qeviz")
  expect_identical(ena.plot(set, backend = "plotly")$get("backend"), "plotly")
})

test_that("scale.to and dimension.labels map onto qeviz", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .backend_set()
  g <- function(...) ena.plot(set, backend = "qeviz", ...)$plot$x$graph
  expect_match(g(scale.to = "points"), 'range="points"', fixed = TRUE)
  expect_match(g(scale.to = 2.5), 'range="2.5"', fixed = TRUE)
  expect_match(g(dimension.labels = c("SVD1", "SVD2")), '<qe-axes x="SVD1" y="SVD2">', fixed = TRUE)
  expect_error(ena.plot(set, backend = "qeviz", scale.to = list(x = c(-1, 1))), "symmetric")
})

test_that("a qeviz-backend $plot is read-only; unknown backends error", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .backend_set()
  p <- ena.plot(set, backend = "qeviz")
  expect_error(p$plot <- NULL, "read-only")
  expect_error(ena.plot(set, backend = "ggplot"), "should be one of")
})
