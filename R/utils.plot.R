
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

#' Title
#'
#' @param x
#' @param wh
#' @param ...
#'
#' @return
#' @export
with_trajcetory <- function(
  x, by, ...,
  add_jitter = TRUE,
  frame = 1100,
  transition = 1000,
  easing = "circle-in-out"
) {
  set = x$enaset
  args = list(...)

  clean_data = clean_trajectory_data(set)
  meta_data = unique(set$meta.data)
  setkey(clean_data, ENA_UNIT)
  setkey(meta_data, ENA_UNIT)
  clean_data = meta_data[clean_data]
  group_var = set$`_function.params`$groupVar
  setkeyv(clean_data, by)


  # if (!is.null(group_var)) {
  #   clean_data$color = clean_data[[group_var]]
  # }
  size = ifelse(is.null(args$size), 10, args$size)
  opacity = ifelse(is.null(args$opacity), 1, args$opacity)

  dims = as.matrix(remove.meta.data(clean_data)[, 1:2])
  if(add_jitter) {
    dims[, 1] = jitter(dims[, 1])
    dims[, 2] = jitter(dims[, 2])
  }

  if(is.null(args$scale)) {
    max_abs = max(abs(dims))
    scale = c(-1*max_abs, max_abs)
  } else {
    scale = args$scale
  }

  ax <- list(
    range = scale, title = "",
    zeroline = TRUE, showline = FALSE,
    showticklabels = FALSE, showgrid = FALSE
  )

  # browser()
  thisPlot <- clean_data %>%
    plot_ly(
      x = dims[,1], y = dims[,2],
      text = ~ENA_UNIT,
      frame = as.formula(paste0("~", by)),
      type = 'scatter',
      mode = 'markers',
      marker = list(
        size = size,
        opacity = opacity,
        hoverinfo = "text",
        color = as.numeric(as.factor(clean_data[[group_var]]))
        # color = as.formula(paste0("~", group_var))
      )
    ) %>%
    layout(
      xaxis = ax,
      yaxis = ax,
      showlegend = T
    ) %>%
    animation_opts(
      frame = frame,
      transition = transition,
      easing = easing,
      redraw = T
    )

  return(thisPlot)
}

#' Title
#'
#' @param x
#'
#' @return
#' @export
clean_trajectory_data <- function(
  x,
  by = x$`_function.params`$conversation[1],
  rotation_matrix = x$rotation.matrix
) {
  points = x$points
  rotation_matrix = as.matrix(rotation_matrix)
  units <- x$trajectories #points[, !find.meta.cols(points), with = FALSE]
  unique_unit_values <- unique(units[, c(x$`_function.params`$units, "ENA_UNIT"), with = FALSE])
  full_data <- cbind(units, as.matrix(points) %*% rotation_matrix)
  full_data <- full_data[, unique(names(full_data)), with = FALSE]

  all_steps_w_zero <- data.table(rbind(
    rep(0, length(by)),
    expand.grid(
      sapply(by, function(b) sort(unique(x$trajectories[[b]]))),
      stringsAsFactors = F
    )
  ))
  colnames(all_steps_w_zero) <- by
  all_step_data <- CJ(all_steps_w_zero[[by]], unique_unit_values$ENA_UNIT)
  colnames(all_step_data) <- c(by, "ENA_UNIT")
  all_step_data[, colnames(rotation_matrix) := 0]
  all_step_data[[by]] = as.ena.metadata(all_step_data[[by]])
  all_step_data = merge(unique_unit_values, all_step_data, by = "ENA_UNIT")
  setkey(all_step_data, "ENA_UNIT")

  filled_data = all_step_data[ , {
      by_names = names(.BY)
      user_rows = sapply(1:length(by_names), function(n) {
          full_data[[by_names[n]]] == .BY[n]
      })
      existing_row = which(rowSums(user_rows * 1) == 2)
      if(length(existing_row) > 0) {
        full_data[existing_row, colnames(rotation_matrix), with = FALSE]
      } else {
        prev_row = tail(full_data[ENA_UNIT == .BY$ENA_UNIT & full_data[[by]] < .BY[[by]],], 1)
        if(nrow(prev_row) == 0) {
          data.table(matrix(rep(0, ncol(rotation_matrix)), nrow = 1, dimnames = list(NULL, colnames(rotation_matrix))))
        } else {
          prev_row[, colnames(rotation_matrix), with = FALSE]
        }
      }

  },  by = c("ENA_UNIT", by)]
  return(filled_data)
}
