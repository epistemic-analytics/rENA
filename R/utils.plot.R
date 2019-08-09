
#####
#' Plot an ena.set object
#'
#' @param x ena.set to plot
#' @param y ignored.
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
#'   add_points(Condition$FirstGame, colors = "blue", with.mean = TRUE) %>%
#'   add_points(Condition$SecondGame, colors = "red", with.mean = TRUE)
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
#' @param ... additional parameters to pass along
#' @param name name to give the plot
#' @param mean include a mean point for the provided points
#'
#' @return ena.plot.object
#' @export
add_points <- function(x, wh = NULL, ..., name = "plot", mean = NULL) {
  set <- x$enaset

  wh_subbed <- as.character(substitute(wh))
  if (!is.null(wh_subbed) && length(wh_subbed) > 0) {
    if (length(wh_subbed) > 1 && wh_subbed[[2]] %in% colnames(set$points)) {
      cc <- call(wh_subbed[[1]], set$points, wh_subbed[[2]])
      part1 <- eval(cc)
      points <- as.matrix(set$points)[part1 == wh_subbed[[3]], ]
      name <- tail(wh_subbed, 1)
    } else {
      points <- wh
    }
  } else {
    points <- as.matrix(set$points)
    name <- "all.points"
  }

  x <- ena.plot.points(x, points = points, ...)
  if(!is.null(mean) && (is.list(mean) || mean == T)) {
    more.args <- list(...)

    if (is.list(mean)) {
      more.args <- c(mean, more.args[!names(more.args) %in% names(mean)])
    }
    more.args$enaplot <- x
    more.args$points <- points
    more.args$labels <- name

    x <- do.call(ena.plot.group, more.args)
  }

  return(x)
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
add_trajectory <- function(x, wh = NULL, ..., name = "plot") {
  set <- x$enaset

  subbed <- substitute(wh)
  args_list <- as.character(subbed)
  points <- set$points

  if (!is.null(args_list) && !is.null(subbed)) {
    if (length(args_list) > 1) {
      # points <- points[eval(call(
      #             args_list[1], 
      #             set$points[[args_list[2]]],
      #             as.character(subbed[[3]])
      #           )), ]

      wh_subbed <- as.character(substitute(wh))
      cc <- call(wh_subbed[[1]], set$points, wh_subbed[[2]])
      part1 <- eval(cc)
      points <- set$points[part1 == wh_subbed[[3]], ]

      by <- "ENA_UNIT"
    } else {
      by <- args_list[[1]]
    }
  } else {
    by <- "ENA_UNIT"
  }
  x <- ena.plot.trajectory(x, points = points, by = by)

  x
}

#' Add a group mean to an ena.plot
#'
#' @param x ena.plot object to plot on
#' @param wh which points to plot as the trajectory
#' @param ... additional parameters to pass along
#'
#' @return ena.plot.object
#' @export
add_group <- function(x, wh = NULL, ...) {
  set <- x$enaset
  arg_list <- list(...)
  wh.clean <- substitute(wh)

  if (
    identical(as.character(wh.clean), "wh.clean") ||
    identical(as.character(wh.clean), "y")
  ) {
    wh.clean <- wh;
  }

  if (is.null(wh.clean)) { #, "ena.points")) {
    x <- ena.plot.group(x, ...)
  } else {
    parts <- as.character(wh.clean)

    if (parts[2] %in% colnames(set$line.weights)) {
      label <- parts[3]
      group.rows <- set$points[set$points[[parts[2]]] == parts[3], ]
      if(nrow(group.rows) > 0) {
        group.means <- colMeans(group.rows)
      
        x <- ena.plot.group(x, points = group.means, labels = label, ...)
      } else {
        warning("No points in the group")
      } 
    } else {
      warning("Unable to plot group")
    }
  }

  return(x)
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
add_network <- function(x, wh = NULL, ..., with.mean = F) {
  set <- x$enaset
  wh.clean <- substitute(wh)
  arg_list <- list(...)

  if(is.null(wh.clean)) { #, "ena.points")) {
    x <- ena.plot.network(
      x,
      network = colMeans(x$enaset$line.weights),
      points = x$enaset$rotation$nodes[, 1:2],
      ...
    )

    if (with.mean) {
      x <- add_group(x, points = set$points, ...)
    }
  } else {
    parts <- as.character(wh.clean)

    if (length(wh.clean) > 1 && is.call(wh.clean[[2]])) {
      means <- sapply(c(wh.clean[[2]], wh.clean[[3]]), function(y) {
        parts <- as.character(y)

        if(with.mean) {
          x <- add_group(x, y,
                colors = default.colors[length(attr(x, "means")) + 1], ...)
        }

        colMeans(set$line.weights[set$line.weights[[parts[2]]] == parts[3], ])
      })

      group.means <- means[, 1] - means[, 2]
    } else {
      if (parts[2] %in% colnames(set$line.weights)) {
        group.means <- colMeans(
          set$line.weights[set$line.weights[[parts[2]]] == parts[3], ]
        )

        if (with.mean) {
          x <- add_group(x, wh.clean, ...)
        }
      } else {
        wgts <- get(as.character(wh.clean), envir = parent.frame())
        group.means <- colMeans(wgts)
        if (with.mean) warning("Not able to determine mean automatically")
      }
    }

    x <- ena.plot.network(x,
          network = group.means,
          points = as.matrix(x$enaset$rotation$nodes)[, 1:2], ...)
  }

  return(x)
}
