# Plotting unordered networks with self-connections (accumulate(self_connections
# = TRUE)): the network has p(p+1)/2 weights, upper triangle with the diagonal.
# Each self weight is a circle on its node, on the edges' width scale, and
# counts once toward the node's size.

psc_qe_ready <- function() {
  requireNamespace("qeviz", quietly = TRUE) && utils::packageVersion("qeviz") >= "0.5.0"
}
psc_codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
               "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
psc_set <- function(...) suppressWarnings(
  RS.data |> accumulate(c("Condition", "UserName"), psc_codes, c("Condition", "GroupName"),
                        default_window = 4, ...) |> model()
)
psc_mean <- function(set, cond) {
  lw <- as.matrix(set$line.weights)
  colMeans(lw[set$meta.data$Condition == cond, , drop = FALSE])
}
psc_traces <- function(p) {
  b <- plotly::plotly_build(p$plot)$x$data
  list(
    self  = Filter(function(t) identical(t$mode, "markers") && !is.null(t$marker$size), b),
    lines = Filter(function(t) identical(t$mode, "lines"), b),
    nodes = Filter(function(t) identical(t$mode, "markers+text"), b)[[1]]
  )
}

test_that("namesToAdjacencyKey(diagonal = TRUE) is the self-connection layout", {
  key <- namesToAdjacencyKey(c("A", "B", "C"), diagonal = TRUE)
  expect_equal(paste(key[1, ], key[2, ], sep = " & "),
               c("A & A", "A & B", "B & B", "A & C", "B & C", "C & C"))
  expect_equal(namesToAdjacencyKey(c("A", "B", "C")), matrix(c("A", "B", "A", "C", "B", "C"), 2))
})

test_that("plotly: self weights draw as circles as wide as an edge of the same weight", {
  set <- psc_set(self_connections = TRUE)
  v <- psc_mean(set, "FirstGame")
  v <- v / max(abs(v))
  p <- ena.plot(set) |> ena.plot.network(network = v)
  tr <- psc_traces(p)
  key <- as.matrix(set$rotation$adjacency.key)
  is_self <- key[1, ] == key[2, ]
  expect_length(tr$self, sum(v[is_self] != 0))
  expect_length(tr$lines, sum(!is_self))
  mult <- p$get("multiplier")
  expect_equal(unname(sort(sapply(tr$self, function(t) t$marker$size))),
               unname(sort(abs(v[is_self][v[is_self] != 0]) * mult)), tolerance = 1e-12)
  expect_equal(sort(sapply(tr$lines, function(t) t$line$width)),
               unname(sort(abs(v[!is_self]) * mult)), tolerance = 1e-12)
  # Each circle sits on its node, which is never smaller than the circle.
  for (t in tr$self) {
    at <- which(abs(tr$nodes$x - t$x) < 1e-12 & abs(tr$nodes$y - t$y) < 1e-12)
    expect_length(at, 1)
    expect_gte(tr$nodes$marker$size[at], t$marker$size)
  }
})

test_that("plotly: a self weight counts once toward its node's size", {
  set <- psc_set(self_connections = TRUE)
  key <- as.matrix(set$rotation$adjacency.key)
  is_self <- key[1, ] == key[2, ]
  # Only Data's self-connection and the Data & Collaboration pair: Data's
  # weight is self + pair, Collaboration's the pair alone.
  v <- setNames(rep(0, ncol(key)), paste(key[1, ], key[2, ], sep = " & "))
  v["Data & Data"] <- 0.5
  v["Data & Collaboration"] <- 0.25
  tr <- psc_traces(ena.plot(set) |> ena.plot.network(network = v, show.all.nodes = FALSE))
  expect_equal(as.character(tr$nodes$text), c("Data", "Collaboration"))
  expect_gt(tr$nodes$marker$size[1], tr$nodes$marker$size[2])
  expect_length(tr$self, 1)
})

test_that("plotly: subtracted self weights take the positive/negative colours", {
  set <- psc_set(self_connections = TRUE)
  v <- psc_mean(set, "FirstGame") - psc_mean(set, "SecondGame")
  key <- as.matrix(set$rotation$adjacency.key)
  self_v <- v[key[1, ] == key[2, ]]
  tr <- psc_traces(ena.plot(set) |> ena.plot.network(network = v / max(abs(v)),
                                                      colors = c(pos = "red", "blue")))
  hues <- sapply(tr$self, function(t) rgb2hsv(col2rgb(t$marker$color))[1])
  expect_equal(sum(hues < 0.1 | hues > 0.9), sum(self_v > 0))
  expect_equal(sum(abs(hues - 2 / 3) < 0.05), sum(self_v < 0))
})

test_that("plotly: networks without self-connections are unchanged, bad lengths still error", {
  set <- psc_set()
  v <- psc_mean(set, "FirstGame")
  tr <- psc_traces(ena.plot(set) |> ena.plot.network(network = v))
  expect_length(tr$self, 0)
  expect_length(tr$lines, 15)
  expect_error(ena.plot(set) |> ena.plot.network(network = v[-1]), "length 15 \\(or 21")
})

test_that("qeviz: self weights are passed by the diagonal key", {
  skip_if_not(psc_qe_ready(), "qeviz >= 0.5.0 not available")
  set <- psc_set(self_connections = TRUE)
  v <- psc_mean(set, "FirstGame")
  named   <- ena.plot.network(ena.plot(set, backend = "qeviz"), network = v)
  unnamed <- ena.plot.network(ena.plot(set, backend = "qeviz"), network = unname(v))
  expect_identical(unnamed$qe$model$networks, named$qe$model$networks)
  row <- named$qe$model$networks$data[[1]]
  expect_equal(unname(unlist(row[c("Data.Data", "Collaboration.Collaboration")])),
               unname(v[c("Data & Data", "Collaboration & Collaboration")]))
  expect_error(ena.plot.network(ena.plot(set, backend = "qeviz"), network = v[-1]), "21 with self")
})
