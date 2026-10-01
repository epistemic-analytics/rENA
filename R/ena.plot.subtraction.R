### plot subtraction ###

ena.plot.subtraction = function(
  set,
  groupVar = NULL,
  group1 = NULL,
  group2 = NULL,
  points = FALSE,
  mean = FALSE,
  network = TRUE,
  networkMultiplier = 1,
  subtractionMultiplier = 1,
  group1.color = "blue",
  group2.color = "red",
  confidence.interval = "box",
  backend = getOption("rENA.plot.backend", "plotly"),
  ...
) {
  backend <- match.arg(backend, c("plotly", "qeviz"))
  # qeviz: weights unscaled; the multipliers become magnify. When either is
  # set, the side plots are labelled too (at networkMultiplier), as webENA
  # labels its side plots "(scaled 1.0x)".
  any.mult <- networkMultiplier != 1 || subtractionMultiplier != 1
  wm <- .qe_weight_mult(backend, networkMultiplier)
  sm <- .qe_weight_mult(backend, subtractionMultiplier)
  side.mag <- .qe_magnify(backend, networkMultiplier, any.mult)
  sub.mag  <- .qe_magnify(backend, networkMultiplier * subtractionMultiplier, any.mult)
  group1.rows = set$points[[groupVar]] == group1
  group2.rows = set$points[[groupVar]] == group2

  g1.plot = ena.plot(enaset = set, title = group1, backend = backend, magnify = side.mag)
  g2.plot = ena.plot(enaset = set, title = group2, backend = backend, magnify = side.mag)
  sub.plot = ena.plot(enaset = set, title = paste0("Network Subtraction -- ",group1," vs ",group2),
                      backend = backend, magnify = sub.mag)

  if(network == TRUE) {
    g1.lw = as.matrix(set$line.weights)[group1.rows,,drop=FALSE]
    g1.mean.lw = colMeans(g1.lw) * wm

    g2.lw = as.matrix(set$line.weights)[group2.rows,,drop=FALSE]
    g2.mean.lw = colMeans(g2.lw) * wm

    sub = (g1.mean.lw - g2.mean.lw) * sm

    g1.plot = ena.plot.network(g1.plot, network = g1.mean.lw, colors = group1.color)
    g2.plot = ena.plot.network(g2.plot, network = g2.mean.lw, colors = group2.color)
    sub.plot = ena.plot.network(sub.plot, network = sub)
  }

  if(points == TRUE) {
    g1.points.for.plot = as.matrix(set$points)[group1.rows,,drop=FALSE]
    g2.points.for.plot = as.matrix(set$points)[group2.rows,,drop=FALSE]

    g1.plot = ena.plot.points(enaplot = g1.plot, points = g1.points.for.plot, colors = group1.color)
    g2.plot = ena.plot.points(enaplot = g2.plot, points = g2.points.for.plot, colors = group2.color)
    sub.plot = ena.plot.points(enaplot = sub.plot, points = g1.points.for.plot, colors = group1.color)
    sub.plot = ena.plot.points(enaplot = sub.plot, points = g2.points.for.plot, colors = group2.color)
  }

  if(mean == TRUE) {
    g1.points.for.plot = as.matrix(set$points)[group1.rows,,drop=FALSE]
    g2.points.for.plot = as.matrix(set$points)[group2.rows,,drop=FALSE]

    g1.plot = ena.plot.group(g1.plot, g1.points.for.plot, colors = group1.color, labels = group1, confidence.interval = confidence.interval)
    g2.plot = ena.plot.group(g2.plot, g2.points.for.plot, colors = group2.color, labels = group2, confidence.interval = confidence.interval)
    sub.plot = ena.plot.group(sub.plot, g1.points.for.plot, colors = group1.color, labels = group1, confidence.interval = confidence.interval)
    sub.plot = ena.plot.group(sub.plot, g2.points.for.plot, colors = group2.color, labels = group2, confidence.interval = confidence.interval)
  }

  else if(TRUE %in% c(network,points, mean) == FALSE) {
    stop("You must set at least one of points, mean, or network to TRUE to obtain a plot.")
  }

  set$plots[[group1]] = g1.plot
  set$plots[[group2]] = g2.plot
  set$plots[[paste0(group1,"-",group2)]] = sub.plot

  return(set)
}
