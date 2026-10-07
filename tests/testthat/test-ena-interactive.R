context("ena.plot.interactive (qeviz widget)")

.qe_ready <- function() {
  requireNamespace("qeviz", quietly = TRUE) && utils::packageVersion("qeviz") >= "0.5.0"
}

.interactive_set <- function() {
  data(RS.data, package = "rENA", envir = environment())
  codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
             "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
  ena.make.set(ena.accumulate.data(
    units        = RS.data[, c("Condition", "UserName")],
    conversation = RS.data[, c("Condition", "GroupName")],
    codes        = RS.data[, codes],
    window.size.back = 4))
}

test_that("default plot: first group's network and mean with CI, no outlier", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  w <- ena.plot.interactive(.interactive_set(), group_col = "Condition")
  expect_s3_class(w, "htmlwidget")
  expect_s3_class(w, "qeviz")
  expect_match(w$x$graph, '<qe-edges group="FirstGame">', fixed = TRUE)
  expect_match(w$x$graph, '<qe-means groups="FirstGame" confidence', fixed = TRUE)
  expect_false(grepl("outlier", w$x$graph, fixed = TRUE))
  expect_match(w$x$graph, "<qe-axes>", fixed = TRUE)
})

test_that("subtraction, outlier, dims and labels map onto qeviz", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  w <- ena.plot.interactive(.interactive_set(), group_col = "Condition",
                            group = "FirstGame", compare = "SecondGame",
                            outlier = TRUE, dim_cols = c("SVD1", "SVD3"),
                            label_nodes = "off")
  expect_match(w$x$graph, 'group="FirstGame" compare="SecondGame"', fixed = TRUE)
  expect_match(w$x$graph, 'groups="FirstGame,SecondGame" confidence outlier', fixed = TRUE)
  expect_match(w$x$graph, '<qe-nodes label="off">', fixed = TRUE)
  m <- jsonlite::fromJSON(w$x$model, simplifyVector = FALSE)
  expect_identical(c(m$x_col, m$y_col), c("SVD1", "SVD3"))
})

test_that("unit network and no group column draw no means", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .interactive_set()
  u <- as.character(set$points$ENA_UNIT[1])
  w <- ena.plot.interactive(set, group_col = "Condition", unit = u)
  expect_match(w$x$graph, sprintf('<qe-edges unit="%s">', u), fixed = TRUE)
  expect_false(grepl("<qe-means", w$x$graph, fixed = TRUE))
  w2 <- ena.plot.interactive(set)
  expect_false(grepl("<qe-means", w2$x$graph, fixed = TRUE))
  expect_null(jsonlite::fromJSON(w2$x$model)$groups)
})

test_that("confidence = FALSE drops the CI; iqr_factor is deprecated", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .interactive_set()
  w <- ena.plot.interactive(set, group_col = "Condition", confidence = FALSE)
  expect_match(w$x$graph, 'intervals="none"', fixed = TRUE)
  expect_warning(ena.plot.interactive(set, group_col = "Condition", iqr_factor = 3),
                 "deprecated")
})

test_that("ena.export.html writes a self-contained page", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")
  f <- tempfile(fileext = ".html")
  expect_message(ena.export.html(.interactive_set(), f, group_col = "Condition"), "Written")
  html <- paste(readLines(f, warn = FALSE), collapse = "\n")
  expect_match(html, "HTMLWidgets.widget", fixed = TRUE)
  expect_match(html, "qe-edges", fixed = TRUE)
})

test_that("Shiny wrappers delegate to qeviz", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  skip_if_not_installed("shiny")
  expect_match(as.character(enaInteractiveOutput("p")), "qeviz html-widget", fixed = TRUE)
  expect_true(is.function(renderEnaInteractive(ena.plot.interactive(.interactive_set(),
                                                                    group_col = "Condition"))))
})
