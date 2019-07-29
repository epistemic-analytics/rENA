
#' @export
plot.ena.set <- function(x, ...) {
  ena.plot(x, ...)
}

points <- function(x, wh = NULL, mean = F, labels = T, label.text = NULL, ...) {
  set = x$enaset
  parts = as.character(substitute(wh))
  points = set$points[set$points[[parts[2]]] == parts[3],]


  if(labels && is.null(label.text)) {
    label.values = as.character(points$ENA_UNIT);
  }

  if(mean == T) {
    x = group(x, points = colMeans(points), labels = parts[3], legend.name = parts[3], ...)
  }
  x = ena.plot.points(x, points = as.matrix(points), labels = label.values, legend.name = paste0(parts[3],".","points"), ...)

  x
}

#' @export
add_points <- function(x, wh = NULL, name = "plot", ...) {
  set = x
  # browser()
  args = as.character(substitute(wh))
  if(!is.null(args) && length(args) > 1) {
    cc = call("$", set$points, args[[2]])
    part1 = eval(cc)
    points = part1[args[[3]], "points" ,set]
    name = args[[length(args)]]
  } else {
    points = as.matrix(set$points)
    name = "all.points"
  }

  set$model$plots[[name]] = ena.plot.points(x$model$plots[[name]], points = points, ...)

  set
}

#' @export
group <- function(x, wh = NULL,  ...) {
  set = x$enaset
  args = list(...)
  wh.clean = substitute(wh)

  if(identical(as.character(wh.clean), "wh.clean") || identical(as.character(wh.clean), "y")) {
    wh.clean = wh;
  }

  if(is.null(wh.clean)) { #, "ena.points")) {
    x = ena.plot.group(x, ...)
  } else {
    parts = as.character(wh.clean)
    label = parts[3]
    group.means = colMeans(set$points[set$points[[parts[2]]] == parts[3],])

    x = ena.plot.group(x, points = group.means, labels = label, ...)
  }

  x
}

#' @export
network <- function(x, wh = NULL, with.mean = T, ...) {
  set = x$enaset
  wh.clean = substitute(wh)
  args = list(...)

  if(is.null(wh.clean)) { #, "ena.points")) {
    x = ena.plot.network(x, network = colMeans(x$enaset$line.weights), points = x$enaset$rotation$nodes[,1:2] ,...)
    if(with.mean) {
      x = group(x, ...)
    }
  } else {
    parts = as.character(wh.clean)
    if(is.call(wh.clean[[2]])) {
      means = sapply(c(wh.clean[[2]], wh.clean[[3]]), function(y) {
        parts = as.character(y)

        if(with.mean)
          x = group(x, y, colors = default.colors[length(attr(x, "means"))+1], ...)

        colMeans(set$line.weights[set$line.weights[[parts[2]]] == parts[3],])
      })

      group.means = means[,1] - means[,2]
    } else {
      group.means = colMeans(set$line.weights[set$line.weights[[parts[2]]] == parts[3],])

      if(with.mean)
        x = group(x, wh.clean, ...)
    }

    x = ena.plot.network(x, network = group.means, points = as.matrix(x$enaset$rotation$nodes)[,1:2], ...)
  }

  x
}
