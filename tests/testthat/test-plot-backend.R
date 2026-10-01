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

# ── Phase 2: layer functions ─────────────────────────────────────────────────

.lw_mean <- function(set, rows) colMeans(as.matrix(set$line.weights[rows]))

test_that("ena.plot.network adds an explicit qeviz network", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .backend_set()
  first <- set$points$Condition == "FirstGame"
  v <- .lw_mean(set, first)
  p <- ena.plot.network(ena.plot(set, backend = "qeviz"), network = v)
  expect_match(p$plot$x$graph, '<qe-edges network="network 1" colors="#4477AA,#EE6677">', fixed = TRUE)
  row <- p$qe$model$networks$data[[1]]
  expect_equal(unname(unlist(row[setdiff(names(row), "name")])),
               unname(v), tolerance = 1e-12)
})

test_that("unnamed network vectors follow the adjacency key, as on plotly", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .backend_set()
  v <- .lw_mean(set, set$points$Condition == "FirstGame")
  named   <- ena.plot.network(ena.plot(set, backend = "qeviz"), network = v)
  unnamed <- ena.plot.network(ena.plot(set, backend = "qeviz"), network = unname(v))
  expect_identical(unnamed$qe$model$networks, named$qe$model$networks)
  expect_error(ena.plot.network(ena.plot(set, backend = "qeviz"), network = v[-1]), "length")
})

test_that("network threshold, colours, multiplier, labels and layers map onto qeviz", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .backend_set()
  v <- .lw_mean(set, set$points$Condition == "FirstGame")
  p <- ena.plot.network(ena.plot(set, backend = "qeviz", multiplier = 10), network = v,
                        threshold = c(0.05, 0.15), colors = I("blue"), labels.hide = TRUE,
                        show.all.nodes = FALSE)
  g <- p$plot$x$graph
  expect_match(g, 'colors="#0000FF" threshold="0.05,0.15" magnify="2"', fixed = TRUE)
  expect_match(g, '<qe-nodes label="off" unconnected="hide">', fixed = TRUE)
  expect_match(ena.plot.network(ena.plot(set, backend = "qeviz"), network = v,
                                layers = "nodes")$plot$x$graph, "<qe-nodes", fixed = TRUE)
  expect_false(grepl("<qe-edges", ena.plot.network(ena.plot(set, backend = "qeviz"),
                                                   network = v, layers = "nodes")$plot$x$graph))
  lab <- ena.plot.network(ena.plot(set, backend = "qeviz"), network = v,
                          labels = paste0("c", seq_len(nrow(set$rotation$nodes))))
  expect_identical(lab$qe$model$nodes$data[[1]]$label, "c1")
})

test_that("unsupported network arguments warn once per session", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .backend_set()
  v <- .lw_mean(set, set$points$Condition == "FirstGame")
  rm(list = ls(.qe_warned), envir = .qe_warned)
  expect_warning(ena.plot.network(ena.plot(set, backend = "qeviz"), network = v, node.size = c(1, 5)),
                 "node.size")
  expect_silent(ena.plot.network(ena.plot(set, backend = "qeviz"), network = v, node.size = c(1, 5)))
  expect_warning(ena.plot.network(ena.plot(set, backend = "qeviz"), network = v, edge_type = "dash"),
                 "solid")
})

test_that("ena.plot.points adds a point set with colours, shapes, texts and sizes", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .backend_set()
  first <- set$points$Condition == "FirstGame"
  p <- ena.plot.points(ena.plot(set, backend = "qeviz"), points = set$points[first],
                       colors = "red", shape = "triangle-up", texts = "u", point.size = 8)
  ps <- p$qe$model$pointsets$data
  expect_length(ps, sum(first))
  expect_identical(ps[[1]]$ENA_UNIT %||% ps[[1]]$id, as.character(set$points$ENA_UNIT[first][1]))
  expect_identical(ps[[1]]$color, "#FF0000")
  expect_identical(ps[[1]]$shape, "triangle")
  expect_identical(ps[[1]]$label, "u")
  expect_match(p$plot$x$graph, '<qe-points set="points 1"', fixed = TRUE)
  expect_equal(p$qe$graph_opts[["point-sets"]][[1]]$size, 4)
})

test_that("ena.plot.group draws means with per-call intervals and outlier", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .backend_set()
  first  <- set$points$Condition == "FirstGame"
  second <- set$points$Condition == "SecondGame"
  p <- ena.plot(set, backend = "qeviz")
  p <- ena.plot.group(p, set$points[first], colors = "red", labels = "FirstGame",
                      confidence.interval = "box")
  p <- ena.plot.group(p, set$points[second], colors = "blue", labels = "SecondGame",
                      confidence.interval = "crosshairs", outlier.interval = "box")
  rows <- p$qe$model$groups$data
  by <- function(lbl) Filter(function(r) identical(r$group, lbl), rows)[[1]]
  pts <- as.matrix(remove_meta_data(set$points[first]))
  expect_equal(by("FirstGame")[[p$qe$model$x_col]], mean(pts[, 1]))
  expect_equal(by("FirstGame")[[paste0(p$qe$model$x_col, ".low")]], t.test(pts[, 1])$conf.int[1])
  expect_identical(by("FirstGame")$intervals, "box")
  expect_false(by("FirstGame")$outlier)
  expect_identical(by("SecondGame")$intervals, "crosshairs")
  expect_true(by("SecondGame")$outlier)
  expect_identical(by("SecondGame")$color, "#0000FF")
})

test_that("ena.plot.group splits by per-point colours and rejects other methods", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .backend_set()
  cols <- ifelse(set$points$Condition == "FirstGame", "red", "blue")
  p <- ena.plot.group(ena.plot(set, backend = "qeviz"), set$points, colors = cols,
                      labels = c("First", "Second"))
  expect_setequal(vapply(p$qe$model$groups$data, `[[`, "", "group"), c("First", "Second"))
  expect_error(ena.plot.group(ena.plot(set, backend = "qeviz"), set$points, method = "median"),
               "mean")
})

# ── Phase 3: composites ──────────────────────────────────────────────────────

.net_row <- function(p) {
  row <- p$qe$model$networks$data[[1]]
  unlist(row[setdiff(names(row), "name")])
}

test_that("ena.plotter subtraction on qeviz: raw weights, multipliers as magnify", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .backend_set()
  first  <- set$points$Condition == "FirstGame"
  second <- set$points$Condition == "SecondGame"
  out <- ena.plotter(set, groupVar = "Condition", groups = c("FirstGame", "SecondGame"),
                     mean = TRUE, subtractionMultiplier = 2, backend = "qeviz")
  expect_named(out$plots, c("FirstGame", "SecondGame", "FirstGame-SecondGame"), ignore.order = TRUE)
  sub <- out$plots[["FirstGame-SecondGame"]]
  expect_identical(sub$get("backend"), "qeviz")
  expect_equal(unname(.net_row(sub)),
               unname(.lw_mean(set, first) - .lw_mean(set, second)), tolerance = 1e-6)
  expect_match(sub$plot$x$graph, 'magnify="2"', fixed = TRUE)
  expect_match(out$plots[["FirstGame"]]$plot$x$graph, 'magnify="1"', fixed = TRUE)
  expect_equal(unname(.net_row(out$plots[["FirstGame"]])), unname(.lw_mean(set, first)), tolerance = 1e-6)
  expect_setequal(vapply(sub$qe$model$groups$data, `[[`, "", "group"), c("FirstGame", "SecondGame"))
})

test_that("ena.plotter without multipliers adds no magnify; plotly path unchanged", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .backend_set()
  out <- ena.plotter(set, groupVar = "Condition", groups = "FirstGame", backend = "qeviz")
  expect_false(grepl("magnify", out$plots[[1]]$plot$x$graph))
  old <- options(rENA.plot.backend = "qeviz"); on.exit(options(old))
  expect_identical(ena.plotter(set, unit = as.character(set$points$ENA_UNIT[1]))$plots[[1]]$get("backend"),
                   "qeviz")
  expect_s3_class(ena.plotter(set, groupVar = "Condition", groups = "FirstGame",
                              backend = "plotly")$plots[[1]]$plot, "plotly")
})

test_that("add_network(edge.multiplier) becomes the layer's magnify on qeviz", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .backend_set()
  first <- set$points$Condition == "FirstGame"
  m <- as.matrix(set$line.weights)[first, ]
  p <- add_network(ena.plot(set, backend = "qeviz"), wh = m, edge.multiplier = 2)
  expect_match(p$plot$x$graph, 'magnify="2"', fixed = TRUE)
  expect_equal(unname(.net_row(p)), unname(colMeans(m)), tolerance = 1e-6)
})

test_that("check_range grows / shrinks the qeviz range as on plotly", {
  skip_if_not(.qe_ready(), "qeviz >= 0.5.0 not available")
  set <- .backend_set()
  p <- add_points(ena.plot(set, backend = "qeviz"))
  p <- check_range(p)
  pts_max  <- max(abs(as.matrix(remove_meta_data(set$points))))
  nodes <- as.data.frame(set$rotation$nodes)
  node_ext <- max(abs(as.matrix(nodes[, vapply(nodes, is.numeric, logical(1))][, 1:2]))) * 1.2
  r <- p$qe$graph_opts[["range"]]
  if (pts_max * 1.2 > node_ext || pts_max < node_ext * 0.5) expect_equal(r, pts_max * 1.2)
  else expect_identical(r, "network")
})
