
#####
#' Plot an ena.set object
#'
#' @param x ena.set to plot
#' @param y ignored
#' @param ... Additional parameters passed along to ena.plot functions
#'
#' @examples
#' library(magrittr)
#'
#' data(RS.data)
#'
#' codeNames = c('Data','Technical.Constraints','Performance.Parameters',
#'   'Client.and.Consultant.Requests','Design.Reasoning','Collaboration');
#'
#' accum = ena.accumulate.data(
#'   units = RS.data[,c("UserName","Condition")],
#'   conversation = RS.data[,c("Condition","GroupName")],
#'   metadata = RS.data[,c("CONFIDENCE.Change","CONFIDENCE.Pre","CONFIDENCE.Post")],
#'   codes = RS.data[,codeNames],
#'   window.size.back = 4
#' )
#'
#' set = ena.make.set(
#'   enadata = accum
#' )
#'
#' plot(set) %>%
#'   add_points(Condition$FirstGame, colors = "blue", mean = T) %>%
#'   add_points(Condition$SecondGame, colors = "red", mean = T)
#'
#' plot(set) %>%
#'   add_network(Condition$FirstGame - Condition$SecondGame)
#'
#' @return ena.plot.object
#' @export
#####
plot.ena.set <- function(x, y, ...) {
  ena.plot(x, ...)
}


#' Plot points on an ena.plot
#'
#' @param x ena.plot to add point on
#' @param wh which points to plot
#' @param name name to give the plot
#' @param ... additional parameters to pass along
#'
#' @return ena.plot.object
#' @export
add_points <- function(x, wh = NULL, name = "plot", ...) {
  set = x$enaset

  args = as.character(substitute(wh))
  if(!is.null(args) && length(args) > 1) {
    cc = call("$", set$points, args[[2]])
    part1 = eval(cc)
    points = as.matrix(set$points)[part1 == args[[3]],] # part1[args[[3]], "points" ,set]
    name = tail(args, 1)
  } else {
    points = as.matrix(set$points)
    name = "all.points"
  }

  x = ena.plot.points(x, points = points, ...)

  x
}

#' Plot a trajectory on an ena.plot
#'
#' @param x ena.plot object to plot on
#' @param wh which points to plot as the trajectory
#' @param name Name, as a character vector, to give the plot
#' @param ... additional parameters to pass along
#'
#' @return ena.plot.object
#' @export
add_trajectory <- function(x, wh = NULL, name = "plot", ...) {
  set = x$enaset

  subbed = substitute(wh)
  args = as.character(subbed)
  points = set$points
  if(!is.null(args)) {
    if(length(args) > 1) {
      # cc = call("$", set$points, args[[2]])
      # part1 = eval(cc)
      # points = part1[args[[3]], "points" ,set]
      # name = args[[length(args)]]
      # by =
      points = points[eval(call(args[1], set$points[[args[2]]], subbed[[3]])), ]
      by = "ENA_UNIT"
    } else {
      # cc = call("[[", set$points, args[[1]])
      # by = eval(cc)
      by = args[[1]]
    }
  } else {
    by = "ENA_UNIT"
  }
  set$model$plots[[name]] = ena.plot.trajectory(x, points = points, by = by)

  set
}

#' Add a group mean to an ena.plot
#'
#' @param x ena.plot object to plot on
#' @param wh which points to plot as the trajectory
#' @param ... additional parameters to pass along
#'
#' @return ena.plot.object
#' @export
add_group <- function(x, wh = NULL,  ...) {
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

#' Add a network to an ENA plot
#'
#' @param x ena.plot object to plot wtih
#' @param wh network to plot
#' @param with.mean Logical value, if TRUE plots the mean for the points in the network
#' @param ... Additional parametesr to pass along
#'
#' @return ena.plot.object
#' @export
add_network <- function(x, wh = NULL, with.mean = T, ...) {
  set = x$enaset
  wh.clean = substitute(wh)
  args = list(...)

  if(is.null(wh.clean)) { #, "ena.points")) {
    x = ena.plot.network(x, network = colMeans(x$enaset$line.weights), points = x$enaset$rotation$nodes[,1:2] ,...)
    if(with.mean) {
      x = add_group(x, ...)
    }
  } else {
    parts = as.character(wh.clean)
    if(is.call(wh.clean[[2]])) {
      means = sapply(c(wh.clean[[2]], wh.clean[[3]]), function(y) {
        parts = as.character(y)

        if(with.mean)
          x = add_group(x, y, colors = default.colors[length(attr(x, "means"))+1], ...)

        colMeans(set$line.weights[set$line.weights[[parts[2]]] == parts[3],])
      })

      group.means = means[,1] - means[,2]
    } else {
      group.means = colMeans(set$line.weights[set$line.weights[[parts[2]]] == parts[3],])

      browser()
      if(with.mean)
        x = add_group(x, wh.clean, ...)
    }

    x = ena.plot.network(x, network = group.means, points = as.matrix(x$enaset$rotation$nodes)[,1:2], ...)
  }

  x
}
