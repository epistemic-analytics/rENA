
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
  p = ena.plot(x, ...)
  # p
  # p$enaset = NULL
  x$model$plot = p
  x
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
  set <- x
  plot <- set$model$plot
  more.args <- list(...)

  wh_subbed <- as.character(substitute(wh))
  if (!is.null(wh_subbed) && length(wh_subbed) > 0) {
    if (length(wh_subbed) > 1 && wh_subbed[[2]] %in% colnames(set$points)) {
      cc <- call(wh_subbed[[1]], set$points, wh_subbed[[2]])
      part1 <- eval(cc)
      # points <- as.matrix(set$points)[part1 == wh_subbed[[3]], ]


      name <- paste(wh_subbed[-1], collapse = "$")
      if(grepl(set$model$model.type, pattern="Trajectory")) {
        points <- set$points[part1 == wh_subbed[[3]], ]
        more.args$points = points[, .SD[nrow(.SD)], by = ENA_UNIT]
      } else {
        more.args$points = points <- set$points[part1 == wh_subbed[[3]], ]
      }

      colors = plot$palette[length(plot$plotted$points) + 1]
    } else if (length(wh_subbed) == 1 && wh_subbed[[1]] %in% colnames(set$points)) {
      more.args$points = points = as.matrix(set$points)
      colors = plot$palette[as.numeric(as.factor(set$points[[wh_subbed]])) + length(plot$plotted$points)]
    } else {
      more.args$points = points <- wh
      colors = plot$palette[length(plot$plotted$points) + 1]
    }
  } else {
    more.args$points = points = as.matrix(set$points)
    name <- "all.points"
    colors = plot$palette[length(plot$plotted$points) + 1]
  }

  more.args$enaplot = plot
  more.args$legend.name = name
  if(!is.null(colors)) {
    more.args$colors = colors
  }
  plot <- do.call(ena.plot.points, more.args)
  plot$plotted$points[[name]]$data <- points

  if(!is.null(mean) && (is.list(mean) || mean == T)) {
    if (is.list(mean)) {
      more.args <- c(mean, more.args[!names(more.args) %in% names(mean)])
    }
    more.args$enaplot <- plot
    more.args$points <- points
    more.args$labels <- name

    plot <- do.call(ena.plot.group, more.args)
  }

  set$model$plot <- plot
  return(set)
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
  set <- x
  plot <- set$model$plot

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
  plot <- ena.plot.trajectory(plot, points = points, by = by)

  set$model$plot <- plot
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
add_group <- function(x, wh = NULL, ...) {
  set <- x
  plot <- set$model$plot

  arg_list <- list(...)
  wh.clean <- substitute(wh)

  if (
    identical(as.character(wh.clean), "wh.clean") ||
    identical(as.character(wh.clean), "y")
  ) {
    wh.clean <- wh;
  }

  more_args = list(...)
  more_args$enaplot <- plot
  if(is.null(more_args$color)) {
    more_args$colors = plot$palette[length(plot$plotted$points) + 1]
  }

  if (is.null(wh.clean)) {
    plot <- do.call(ena.plot.group, more_args)
  } else {
    parts <- as.character(wh.clean)

    if (parts[2] %in% colnames(set$line.weights)) {
      label <- parts[3]
      group.rows <- set$points[set$points[[parts[2]]] == parts[3], ]
      if(nrow(group.rows) > 0) {
        group.means <- colMeans(group.rows)

        more_args$points <- group.means
        more_args$labels <- label
        plot <- do.call(ena.plot.group, more_args)
      } else {
        warning("No points in the group")
      }
    } else {
      warning("Unable to plot group")
    }
  }

  set$model$plot <- plot
  set
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
  set <- x
  plot <- set$model$plot

  wh.clean <- substitute(wh)
  arg_list <- list(...)

  if(is.null(wh.clean)) { #, "ena.points")) {
    plot <- ena.plot.network(
      plot,
      network = colMeans(set$line.weights),
      points = set$rotation$nodes[, 1:2],
      ...
    )

    if (with.mean) {
      set <- add_group(set, points = set$points, ...)
      plot <- set$model$plot
    }
  } else {
    parts <- as.character(wh.clean)

    if (length(wh.clean) > 1 && is.call(wh.clean[[2]])) {
      means <- sapply(c(wh.clean[[2]], wh.clean[[3]]), function(y) {
        parts <- as.character(y)

        if(with.mean) {
          set <- add_group(set, y,
                colors = default.colors[length(attr(plot, "means")) + 1], ...)
          plot <- set$model$plot
        }

        colMeans(set$line.weights[set$line.weights[[parts[2]]] == parts[3], ])
      })

      group.means <- means[, 1] - means[, 2]
    } else {
      if (parts[2] %in% colnames(set$line.weights)) {
        group.means <- colMeans(
          as.matrix(set$line.weights[set$line.weights[[parts[2]]] == parts[3], ])
        )

        if (with.mean) {
          set <- add_group(set, wh.clean, ...)
          plot <- set$model$plot
        }
      } else {
        wgts <- get(as.character(wh.clean), envir = parent.frame())
        group.means <- colMeans(wgts)
        if (with.mean) warning("Not able to determine mean automatically")
      }
    }

    plot <- ena.plot.network(plot,
          network = group.means,
          node.positions = as.matrix(set$rotation$nodes)[, 1:2], ...)
  }

  set$model$plot <- plot
  set
}

#' Title
#'
#' @param x [TBD]
#' @param wh [TBD]
#' @param ... [TBD]
#'
#' @return [TBD]
#' @export
with_trajcetory <- function(
  x, ...,
  by = x$`_function.params`$conversation[1],
  add_jitter = TRUE,
  frame = 1100,
  transition = 1000,
  easing = "circle-in-out",
  group_var = x$`_function.params`$groupVar,
  groups = x$`_function.params`$groups
) {
  set = x
  plot = set$model$plot
  args = list(...)

  clean_data = clean_trajectory_data(set)
  meta_data = unique(set$meta.data)
  setkey(clean_data, ENA_UNIT)
  setkey(meta_data, ENA_UNIT)
  clean_data = meta_data[clean_data]
  setkeyv(clean_data, by)

  if (is.null(group_var)) {
    # group_var =
  }

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

  #####
  ### Add to the plot
  #####
    thisPlot <- clean_data %>%
      plotly::plot_ly(
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
      plotly::layout(
        xaxis = ax,
        yaxis = ax,
        showlegend = T
      ) %>%
      plotly::animation_opts(
        frame = frame,
        transition = transition,
        easing = easing,
        redraw = T
      )
  #####

  return(thisPlot)
}

#' Title
#'
#' @param x [TBD]
#'
#' @return [TBD]
#' @export
clean_trajectory_data <- function(
  x = NULL,
  by = x$`_function.params`$conversation[1],
  rotation_matrix = x$rotation.matrix,
  points = NULL,
  units = points,
  units_by = x$`_function.params`$units,
  steps = NULL
) {
  if(is(x, "ena.set")) {
    if(is.null(points))
      points <- x$points
    if(is.null(units))
      units <- x$trajectories #points[, !find.meta.cols(points), with = FALSE]
  }

  unique_unit_values <- unique(units[, c(units_by, "ENA_UNIT"), with = FALSE])

  if(!is.null(rotation_matrix)) {
    rotation_matrix = as.matrix(rotation_matrix)
    full_data <- cbind(units, as.matrix(points) %*% rotation_matrix)
  } else {
    full_data <- cbind(units, as.matrix(points))
  }
  full_data <- full_data[, unique(names(full_data)), with = FALSE]

  if(is.null(steps)) {
    all_steps_w_zero <- data.table(rbind(
      rep(0, length(by)),
      expand.grid(
        sapply(by, function(b) sort(unique(units[[b]]))),
        stringsAsFactors = F
      )
    ))
    colnames(all_steps_w_zero) <- by
  } else {
    all_steps_w_zero <- steps
  }
  all_step_data <- CJ(all_steps_w_zero[[by]], unique_unit_values$ENA_UNIT)
  colnames(all_step_data) <- c(by, "ENA_UNIT")

  dimension_col_names = colnames(points)[
                          which(sapply(points, function(col) {
                            is(col, "ena.dimension")
                          }))
                        ]
  all_step_data[, c(dimension_col_names) := 0]
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
        full_data[existing_row, c(dimension_col_names), with = FALSE]
      } else {
        prev_row = tail(full_data[ENA_UNIT == .BY$ENA_UNIT & full_data[[by]] < .BY[[by]],], 1)
        if(nrow(prev_row) == 0) {
          data.table(matrix(rep(0, length(dimension_col_names)), nrow = 1, dimnames = list(NULL, c(dimension_col_names))))
        } else {
          prev_row[, c(dimension_col_names), with = FALSE]
        }
      }

  },  by = c("ENA_UNIT", by)]
  for(col in dimension_col_names) {
    set(filled_data, j = col, value = as.ena.dimension(filled_data[[col]]))
  }
  return(filled_data)
}

#' Title
#'
#' @param x [TBD]
#'
#' @return [TBD]
#' @export
add_means <- function(x) {
  set <- x
  plot <- set$model$plot

  for(point_group in plot$plotted$points) {
    plot <- ena.plot.group(plot, point_group$points, colors = point_group$color[1])
  }

  set$model$plot <- plot
  set
}

#' Title
#'
#' @param x [TBD]
#' @param ... [TBD]
#' @param by [TBD]
#' @param add_jitter [TBD]
#' @param frame [TBD]
#' @param transition [TBD]
#' @param easing [TBD]
#' @param group_var [TBD]
#' @param groups [TBD]
#'
#' @return [TBD]
#' @export
as_trajectory <- function(
  x, ...,
  by = x$`_function.params`$conversation[1],
  add_jitter = TRUE,
  frame = 1100,
  transition = 1000,
  easing = "circle-in-out"
) {
  args = list(...)

  # points <- rbindlist(lapply(
  #             x$model$plot$plotted$points,
  #             function(ps) { ps$data }
  #           ), idcol = "TRAJ_GROUP")
  # set(
  #   points,
  #   j = which(colnames(points) == "TRAJ_GROUP"),
  #   value = as.ena.metadata(points$TRAJ_GROUP)
  # )
  # class(points) <- class(x$points)
  # points_cleaned <- clean_trajectory_data(
  #   points = points,
  #   by = x$`_function.params`$conversation[1],
  #   units = x$trajectories,
  #   units_by = x$`_function.params`$units
  # )

  all_steps_w_zero <- data.table(rbind(
    rep(0, length(by)),
    expand.grid(
      sapply(by, function(b) sort(unique(x$points[[b]]))),
      stringsAsFactors = F
    )
  ))
  colnames(all_steps_w_zero) <- by
  point_group_names <- names(x$model$plot$plotted$points)
  points_cleaned <- lapply(point_group_names, function(n) {
      clean_trajectory_data(
          points = x$model$plot$plotted$points[[n]]$data,
          by = by,
          units = x$model$plot$plotted$points[[n]]$data,
          units_by = x$`_function.params`$units,
          steps = all_steps_w_zero
      )
  })
  names(points_cleaned) <- sapply(x$model$plot$plotted$points, "[[", "color") #x$model$plot$plotted$points
  points_cleaned <- rbindlist(points_cleaned, idcol = "color")

  meta_data = unique(x$meta.data)
  setkey(points_cleaned, ENA_UNIT)
  setkey(meta_data, ENA_UNIT)
  points_cleaned = meta_data[points_cleaned]
  setkeyv(points_cleaned, by)

  size = ifelse(is.null(args$size), 10, args$size)
  opacity = ifelse(is.null(args$opacity), 1, args$opacity)

  dims = as.matrix(points_cleaned[,find.dimension.cols(points_cleaned), with = F])[, 1:2]
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

  #####
  ### Add to the plot
  #####
    thisPlot <- plotly::plot_ly(
        data = points_cleaned,
        x = dims[,1], y = dims[,2],
        text = ~ENA_UNIT,
        frame = as.formula(paste0("~", by)),
        type = 'scatter',
        mode = 'markers',
        marker = list(
          size = size,
          opacity = opacity,
          hoverinfo = "text",
          color = as.numeric(as.factor(points_cleaned[["color"]]))
          # color = as.formula(paste0("~", group_var))
        )
      ) %>%
      plotly::layout(
        xaxis = ax,
        yaxis = ax,
        showlegend = T
      ) %>%
      plotly::animation_opts(
        frame = frame,
        transition = transition,
        easing = easing,
        redraw = T
      )
  #####


  x$model$plot <- thisPlot
  return(x)
}
