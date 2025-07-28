#' Plot an ena.set object
#'
#' @param x ena.set to plot
#' @param y ignored.
#' @param ... Additional parameters passed along to ena.plot functions
#'
#' @examples
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
#' plot(set) |>
#'   add_points(Condition$FirstGame, colors = "blue", with.mean = TRUE) |>
#'   add_points(Condition$SecondGame, colors = "red", with.mean = TRUE) |>
#'   with_means() |>
#'   add_nodes()
#'
#' myENAplot <- plot(set) |>
#'   add_network(Condition$FirstGame - Condition$SecondGame)
#' 
#' 
#' # Add a group mean to an existing ENA plot
#' add_group(myENAplot, wh = Condition$FirstGame)
#' 
#' # Add a trajectory to an existing ENA plot
#' add_trajectory(myENAplot, wh = Condition$FirstGame)
#' 
#' @example inst/examples/example-plot-piping.R
#' 
#' @return ena.plot.object
#' @export
plot.ena.set <- function(x, y, ...) {
  p = ena.plot(x, ...)
  # p
  # p$enaset = NULL
  x$plots[[length(x$plots) + 1]] = p
  args = list(...)
  if(!is.null(args$title)) {
    names(x$plots)[length(x$plots)] = args$title
  }

  .return(x, from_plot = T, invisible = F)
}


#' Add points to an ENA plot
#'
#' This function adds points to an existing ENA plot or ENA set. It supports various input types for the `wh` parameter, including unevaluated expressions and language objects.
#'
#' @param x An `ENAplot` object or an ENA set containing plots.
#' @param wh Specifies the points to plot. Can be an unevaluated expression or a language object.
#' @param ... Additional parameters passed to the plotting functions.
#' @param name A character string specifying the name of the plot. Default is "plot".
#' @param mean Logical; if `TRUE`, includes a mean point for the provided points. Default is `NULL`.
#' @param colors A vector of colors for the plotted points. Default is `NULL`.
#'
#' @details
#' The function determines the type of the `wh` parameter and processes it accordingly:
#' - If `wh` is an unevaluated expression, it is captured and evaluated in the parent frame.
#' - If `wh` is a language object, it is processed to extract the relevant points information.
#'
#' The function updates the plot with the new points and stores the updated plot back in the ENA set.
#'
#' @example inst/examples/example-plot-piping.R
#' 
#' @return Invisibly returns the modified ENA set.
#'
#' @export
add_points <- function(
  x,
  wh = NULL, ...,
  name = "plot",
  mean = NULL,
  colors = NULL
) {
  set <- x
  plot <- set$plots[[length(set$plots)]]
  more.args <- list(...)

  wh_subbed <- as.character(substitute(wh))
  if (!is.null(wh_subbed) && length(wh_subbed) > 0) {
    if (length(wh_subbed) > 1 && wh_subbed[[2]] %in% colnames(set$points)) {
      cc <- call(wh_subbed[[1]], set$points, wh_subbed[[2]])
      part1 <- eval(cc);
      name <- paste(wh_subbed[-1], collapse = "$");
      if(grepl(set$model$model.type, pattern="Trajectory")) {
        points <- set$points[part1 == wh_subbed[[3]], ]
        more.args$points = points[, .SD[nrow(.SD)], by = ENA_UNIT]
      }
      else {
        more.args$points = points <- set$points[part1 == wh_subbed[[3]], ]
      }

      if(is.null(colors)) {
        colors = plot$palette[length(plot$plotted$points) + 1]
      }
    }
    else if (length(wh_subbed) == 1 && wh_subbed[[1]] %in% colnames(set$points)) {
      more.args$points = points = set$points
      if(is.null(colors)) {
        colors <- plot$palette[as.numeric(as.factor(set$points[[wh_subbed]])) + length(plot$plotted$points)]
      }
      else {
        colors <- colors[as.numeric(as.factor(set$points[[wh_subbed]]))]
      }
    }
    else {
      more.args$points = points <- wh
      colors = ifelse(is.null(colors), plot$palette[length(plot$plotted$points) + 1], colors)
    }
  }
  else {
    more.args$points = points = set$points
    name <- "all.points"
    colors = ifelse(is.null(colors), plot$palette[length(plot$plotted$points) + 1], colors)
  }

  more.args$enaplot = plot
  more.args$legend.name = name
  if(!is.null(colors)) {
    more.args$colors = colors
  }
  else {
    more.args$colors = plot$palette[length(plot$plotted$points) + 1]
  }
  plot <- do.call(ena.plot.points, more.args)

  for(color in unique(more.args$colors)) {
    plot$plotted$points[[length(plot$plotted$points) + 1]] <- list(
      data = more.args$points[color == more.args$colors,],
      color = color
    )
    if(!is.null(name)) {
      names(plot$plotted$points)[length(plot$plotted$points)] = name
    }
  }

  if(!is.null(mean) && (is.list(mean) || mean == T)) {
    # if (is.list(mean)) {
    #   more.args <- c(mean, more.args[!names(more.args) %in% names(mean)])
    # }
    # more.args$enaplot <- plot
    # more.args$points <- points
    # more.args$labels <- name
    #
    # plot <- do.call(ena.plot.group, more.args).
    set <- add_group(set, substitute(wh), ...);
  }

  set$plots[[length(set$plots)]] <- plot
  invisible(set)
}

#' Add a trajectory to an ENA plot
#'
#' This function adds a trajectory to an existing ENA plot or ENA set. It supports various input types for the `wh` parameter, including unevaluated expressions and language objects.
#'
#' @param x An `ENAplot` object or an ENA set containing plots.
#' @param wh Specifies the trajectory to plot. Can be an unevaluated expression or a language object.
#' @param ... Additional parameters passed to the plotting functions.
#' @param name A character string specifying the name of the plot. Default is "plot".
#'
#' @details
#' The function determines the type of the `wh` parameter and processes it accordingly:
#' - If `wh` is an unevaluated expression, it is captured and evaluated in the parent frame.
#' - If `wh` is a language object, it is processed to extract the relevant trajectory information.
#'
#' The function updates the plot with the new trajectory and stores the updated plot back in the ENA set.
#'
#' @return Invisibly returns the modified ENA set.
#'
#' @example inst/examples/example-plot-piping.R 
#'
#' @export
add_trajectory <- function(x, wh = NULL, ..., name = "plot") {
  set <- x
  # plot <- set$model$plot
  plot <- set$plots[[length(set$plots)]]

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
    }
    else {
      by <- args_list[[1]]
    }
  }
  else {
    by <- "ENA_UNIT"
  }
  plot <- ena.plot.trajectory(plot, points = points, by = by)

  # set$model$plot <- plot
  set$plots[[length(x$plots)]] <- plot
  invisible(set)
}


#' Add a group mean to an ENA plot
#'
#' This function adds a group mean to an existing ENA plot or ENA set. It supports various input types for the `wh` parameter, including unevaluated expressions and language objects.
#'
#' @param x An `ENAplot` object or an ENA set containing plots.
#' @param wh Specifies the group to plot. Can be an unevaluated expression or a language object.
#' @param ... Additional parameters passed to the plotting functions.
#'
#' @details
#' The function determines the type of the `wh` parameter and processes it accordingly:
#' - If `wh` is an unevaluated expression, it is captured and evaluated in the parent frame.
#' - If `wh` is a language object, it is processed to extract the relevant group information.
#'
#' The function updates the plot with the new group mean and stores the updated plot back in the ENA set.
#'
#' @example inst/examples/example-plot-piping.R
#' 
#' @return Invisibly returns the modified ENA set.
#'
#' @export
add_group <- function(x, wh = NULL, ...) {
  # Capture the expression passed to wh
  wh.expr <- substitute(wh)

  # Check if the expression is a call to `substitute()`. This happens when
  # add_group is called from another function like add_points, which has
  # already substituted the user's original input.
  if (is.call(wh.expr) && deparse(wh.expr[[1]]) == "substitute") {
    # If so, evaluate it in the parent frame to get the actual language object
    wh.clean <- eval(wh.expr, parent.frame())
  } else {
    # Otherwise, the captured expression is what we want
    wh.clean <- wh.expr
  }

  set <- x
  # plot <- set$model$plot
  plot <- set$plots[[length(set$plots)]]

  arg_list <- list(...)

  if (
    identical(as.character(wh.clean), "wh.clean") ||
    identical(as.character(wh.clean), "y")
  ) {
    wh.clean <- wh;
  }

  more_args = list(...)
  more_args$enaplot <- plot
  if(is.null(more_args$color)) {
    more_args$colors <- plot$palette[length(plot$plotted$means) + 1]
  }
  else {
    more_args$colors <- more_args$color;
  }

  group.rows.log <- NULL;
  if (is.null(wh.clean)) {
    plot <- do.call(ena.plot.group, more_args)
    group.rows.log <- rep(TRUE, nrow(set$points));
  }
  else {
    parts <- as.character(wh.clean)

    if (parts[2] %in% colnames(set$line.weights)) {
      label <- parts[3]
      group.rows.log <- set$points[[parts[2]]] == parts[3];
      group.rows <- set$points[group.rows.log, ]
      if(nrow(group.rows) > 0) {
        group.means <- colMeans(group.rows)

        more_args$points <- group.means
        more_args$labels <- label
        plot <- do.call(ena.plot.group, more_args)
      }
      else {
        warning("No points in the group")
      }
    }
    else {
      warning("Unable to plot group")
    }
  }

  plot$plotted$means[[length(plot$plotted$means) + 1]] = list(
    rows = group.rows.log,
    data = more_args$points,
    color = more_args$colors
  )

  set$plots[[length(set$plots)]] <- plot
  invisible(set)
}


#' Add a network to an ENA plot
#'
#' This function adds a network to an existing ENA plot or ENA set. It supports various input types for the `wh` parameter, including unevaluated expressions, numeric matrices, and language objects.
#'
#' @param x An `ENAplot` object or an ENA set containing plots.
#' @param wh Specifies the network to plot. Can be an unevaluated expression, a numeric matrix, or a language object.
#' @param with.mean Logical; if `TRUE`, plots the mean for the points in the network.
#' @param edge.multiplier Numeric scalar used to multiply the edge weights.
#' @param ... Additional parameters passed to the plotting functions.
#'
#' @details
#' The function determines the type of the `wh` parameter and processes it accordingly:
#' - If `wh` is an unevaluated expression, it is captured and evaluated in the parent frame.
#' - If `wh` is a numeric matrix, it is used directly as the network data.
#' - If `wh` is a language object, it is processed to extract the relevant network information.
#'
#' The function updates the plot with the new network and stores the updated plot back in the ENA set.
#'
#' @example inst/examples/example-plot-piping.R
#' 
#' @return Invisibly returns the modified ENA set.
#'
#' @export
add_network <- function(x, wh = NULL, ..., with.mean = F, edge.multiplier = 1) {
  wh.expr <- substitute(wh);

  # Check if the expression is a call to `substitute()`
  if (is.call(wh.expr) && deparse(wh.expr[[1]]) == "substitute") {
    wh.clean <- eval(wh.expr, parent.frame())
  } 
  else {
    # Evaluate safely to check if it's numeric
    wh.evaluated <- try(eval(wh.expr, parent.frame()), silent = TRUE)
    if (is.numeric(wh.evaluated)) {
      wh.clean <- wh.evaluated
    } 
    else {
      wh.clean <- wh.expr
    }
  }

  set <- x
  
  # plot <- set$model$plot
  plot <- set$plots[[length(set$plots)]];

  arg_list <- list(...);

  if(is.null(wh.clean)) {
    line_weights <- NULL;
    colors <- c(plot$palette[1], plot$palette[2]);

    means_plotted <- length(plot$plotted$means);
    if(means_plotted > 0) {
      line_weights <- colMeans(set$line.weights[plot$plotted$means[[1]]$rows,]);
      colors <- c(plot$plotted$means[[1]]$color);
      if(means_plotted > 1) {
        line_weights <- line_weights - colMeans(set$line.weights[plot$plotted$means[[2]]$rows,]);
        colors <- c(colors, plot$plotted$means[[2]]$color);
      }
    }
    else if(length(plot$plotted$points) && length(plot$plotted$points$plot$data) && nrow(plot$plotted$points$plot$data) == 1) {
      line_weights <- as.matrix(set$line.weights[set$line.weights$ENA_UNIT == plot$plotted$points$plot$data$ENA_UNIT,])
    }
    else {
      line_weights <- colMeans(set$line.weights)
    }

    plot <- ena.plot.network(
      plot,
      network = line_weights * edge.multiplier,
      points = as.matrix(set$rotation$nodes)[, 1:2],
      labels = set$rotation$nodes$code,
      ...
    )
    
    if (with.mean) {
      set <- add_group(set, points = set$points, ...)
      plot <- set$plots[[length(set$plots)]]
    }
  }
  else {
    if(is.numeric(wh.clean)) {
      plot <- ena.plot.network(
        plot,
        network = colMeans(as.matrix(wh.clean)) * edge.multiplier,
        labels = set$rotation$nodes$code,
        ...
      )
    }
    else {
      parts <- as.character(wh.clean)

      if (length(wh.clean) > 1 && is.call(wh.clean[[2]])) {
        means <- sapply(c(wh.clean[[2]], wh.clean[[3]]), function(y) {
          parts <- as.character(y)

          if(with.mean) {
            set <- add_group(set, y,
                  colors = plot$palette[length(attr(plot, "means")) + 1], ...)
            plot <- set$plots[[length(set$plots)]]
          }

          colMeans(set$line.weights[set$line.weights[[parts[2]]] == parts[3], ])
        })

        group.means <- means[, 1] - means[, 2]
      }
      else {
        if (parts[2] %in% colnames(set$line.weights)) {
          group.means <- colMeans(
            as.matrix(set$line.weights[set$line.weights[[parts[2]]] == parts[3], ])
          )

          if (with.mean) {
            set <- add_group(set, wh.clean, ...)
            plot <- set$plots[[length(set$plots)]]
          }
        }
        else {
          wgts <- get(as.character(wh.clean), envir = parent.frame())
          group.means <- colMeans(wgts)
          if (with.mean) warning("Not able to determine mean automatically")
        }
      }

      plot <- ena.plot.network(plot,
          network = group.means * edge.multiplier,
          labels = set$rotation$nodes$code,
          node.positions = as.matrix(set$rotation$nodes)[, 1:2], ...)
    }
  }

  # set$model$plot <- plot
  set$plots[[length(set$plots)]] <- plot
  invisible(set)
}


#' Add nodes to an ENA plot
#'
#' This function adds nodes to an existing ENA plot or ENA set. It can be used to customize the nodes displayed on the plot, including their size and other graphical parameters.
#'
#' @param x An \code{ENAplot} object or an ENA set containing plots.
#' @param ... Additional arguments passed to \code{ena.plot.points}, such as \code{nodes}, \code{size}, and other graphical parameters.
#' @param return_plot Logical; if \code{TRUE}, returns the modified ENA set. If \code{FALSE} (default), returns the modified plot invisibly.
#'
#' @details
#' If \code{x} is an \code{ENAplot}, the function extracts the associated ENA set and plot. Otherwise, it assumes \code{x} is an ENA set and uses the last plot in the set.
#' The nodes to be added can be specified via the \code{nodes} argument; otherwise, the default nodes from the set's rotation are used.
#' Node size can be customized via the \code{size} argument.
#'
#' The function updates the plot with the new nodes and stores the updated plot back in the ENA set.
#'
#' @return Invisibly returns the modified plot or ENA set, depending on the value of \code{return_plot}.
#'
#' @example inst/examples/example-plot-piping.R
#'
#' @seealso \code{\link{ena.plot.points}}
#' @export
add_nodes <- function(x, ..., return_plot = FALSE) {
  if(is(x, "ENAplot")) {
    set <- x$enaset;
    plot <- x;
  }
  else {
    set <- x;
    plot <- set$plots[[length(set$plots)]]
  }

  dot_args <- list(...);
  if(!is.null(dot_args$nodes)) {
    nodes <- dot_args$nodes;
  }
  else {
    nodes <- set$rotation$nodes;
  }

  node_sizes <- 1;
  if(!is.null(dot_args$size)) {
    node_sizes <- dot_args$size;
  }

  plot <- ena.plot.points(plot,
            points = as.matrix(nodes),
            texts = as.character(nodes$code),
            point.size = node_sizes,
            ...
          );

  plot$plotted$networks[[length(plot$plotted$networks) + 1]] <- list(
    nodes = nodes,
    data = NULL,
    color = NULL
  );

  set$plots[[length(set$plots)]] <- plot

  if(!isTRUE(return_plot)) {
    invisible(plot);
  }
  else {
    invisible(set);
  }
}

#' Adds group means to the ENA plot.
#'
#' This function iterates over the plotted points in the ENA plot and calculates
#' the mean for each group of points. The calculated means are then added to the
#' plot as group means.
#'
#' @param x An ENA set object containing the plots.
#'
#' @return Invisibly returns the modified ENA set object with updated plots.
#'
#' @export
with_means <- function(x) {
  set <- x
  # plot <- set$model$plot
  plot <- set$plots[[length(set$plots)]]

  for(point_group in plot$plotted$points) {
    plot <- ena.plot.group(plot, point_group$data, colors = point_group$color[1])

    plot$plotted$means[[length(plot$plotted$means) + 1]] <- list(
      data = colMeans(point_group$data),
      color = point_group$color[1]
    )
  }

  # set$model$plot <- plot
  set$plots[[length(set$plots)]] <- plot
  invisible(set)
}


#' Adds trajectories to an ENA plot.
#'
#' This function generates trajectories for the plotted points in the ENA plot based on the specified grouping variables.
#' It supports options for jittering, animation, and scaling.
#'
#' @param x An ENA set object containing the plots.
#' @param ... Additional arguments passed to the plotting functions.
#' @param by A character vector specifying the grouping variables for the trajectories. Default is the first conversation parameter in the ENA set.
#' @param add_jitter Logical; if `TRUE`, adds jitter to the trajectory points. Default is `TRUE`.
#' @param frame Numeric; the duration of each frame in the animation. Default is 1100.
#' @param transition Numeric; the duration of the transition between frames. Default is 1000.
#' @param easing A character string specifying the easing function for the animation. Default is "circle-in-out".
#'
#' @return Invisibly returns the modified ENA set object with updated plots.
#'
#' @export
with_trajectory <- function(
  x, ...,
  by = x$`_function.params`$conversation[1],
  add_jitter = TRUE,
  frame = 1100,
  transition = 1000,
  easing = "circle-in-out"
) {
  set <- x
  if(!grepl(x = set$model$model.type, pattern = "Trajectory")) {
    stop(paste0("Unable to plot trajectories on model of type: ", set$model$model.type))
  }
  plot <- set$plots[[length(set$plots)]]

  args = list(...)

  all_steps_w_zero <- data.table(rbind(
    rep(0, length(by)),
    expand.grid(
      sapply(by, function(b) sort(unique(set$points[[b]]))),
      stringsAsFactors = F
    )
  ))
  colnames(all_steps_w_zero) <- by
  point_group_names <- seq(plot$plotted$points)
  points_cleaned <- lapply(point_group_names, function(n) {
    prepare_trajectory_data(
      points = plot$plotted$points[[n]]$data,
      by = by,
      units = plot$plotted$points[[n]]$data,
      units_by = set$`_function.params`$units,
      steps = all_steps_w_zero
    )
  })
  names(points_cleaned) <- sapply(plot$plotted$points, "[[", "color")
  points_cleaned <- rbindlist(points_cleaned, idcol = "color")

  meta_data = unique(set$meta.data)
  setkey(points_cleaned, ENA_UNIT)
  setkey(meta_data, ENA_UNIT)
  points_cleaned = meta_data[points_cleaned]
  setkeyv(points_cleaned, by)

  size = ifelse(is.null(args$size), 10, args$size)
  opacity = ifelse(is.null(args$opacity), 1, args$opacity)

  dims = as.matrix(points_cleaned[, find_dimension_cols(points_cleaned), with = F])[, 1:2]
  if(add_jitter) {
    dims[, 1] = jitter(dims[, 1])
    dims[, 2] = jitter(dims[, 2])
  }

  if(is.null(args$scale)) {
    max_abs = max(abs(dims))
    scale = c(-1*max_abs, max_abs)
  }
  else {
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
        )
      ) |>
      plotly::layout(
        xaxis = ax,
        yaxis = ax,
        showlegend = T
      ) |>
      plotly::animation_opts(
        frame = frame,
        transition = transition,
        easing = easing,
        redraw = T
      )
  #####

  # set$model$plot <- plot
  set$plots[[length(set$plots) + 1]] <- thisPlot
  invisible(set)
}

#' Prepares trajectory data for an ENA plot.
#'
#' This function processes and prepares trajectory data for plotting in an ENA set. It handles rotation, grouping, and filling missing steps in the trajectory.
#'
#' @param x An ENA set object. If `NULL`, other parameters must be provided.
#' @param by A character vector specifying the grouping variables for the trajectory. Default is the first conversation parameter in the ENA set.
#' @param rotation_matrix A matrix used to rotate the points. Default is the rotation matrix from the ENA set.
#' @param points A data table of points to be processed. Default is the points from the ENA set.
#' @param units A data table of units corresponding to the points. Default is the trajectories or points from the ENA set.
#' @param units_by A character vector specifying the unit grouping variables. Default is the unit parameters from the ENA set.
#' @param steps A data table specifying the steps for the trajectory. If `NULL`, steps are generated automatically.
#'
#' @return A data table containing the processed trajectory data, including dimensions and metadata.
prepare_trajectory_data <- function(
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
      units <- x$trajectories #points[, find_meta_cols(points), with = FALSE]
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

#' Clears specified plots from an ENA set.
#'
#' This function removes the plots specified by their indices from the `plots` field of the ENA set.
#'
#' @param x An ENA set object containing the plots.
#' @param wh A numeric vector specifying the indices of the plots to clear. Default is all plots.
#'
#' @return Invisibly returns the modified ENA set object with the specified plots removed.
#'
#' @example inst/examples/example-plot-piping.R
#' 
#' @export
clear <- function(x, wh = seq(x$plots)) {
  if(length(wh) > 0) {
    x$plots[[wh]] <- NULL
  }
  invisible(x)
}

#' Scales the points and means in an ENA set.
#'
#' This function adjusts the scale of the points and means in the ENA set to match the range of the network.
#'
#' @param x An ENA set object containing the plots.
#' @param center Logical; if `TRUE`, centers the data before scaling. Default is `TRUE`.
#' @param scale Logical; if `TRUE`, scales the data. Default is `TRUE`.
#'
#' @return Invisibly returns the modified ENA set object with scaled points and means.
#' 
#' @export
scale.ena.set <- function(x, center = TRUE, scale = TRUE) {
  set <- x
  plot <- set$plots[[length(set$plots)]]

  dims <- 1:2
  point_range <- range(sapply(plot$plotted$points, function(d) range(as.matrix(d$data)[,dims])))
  network_range <-range(sapply(plot$plotted$networks, function(n) range(as.matrix(n$nodes)[,dims])))

  scale_factor <- min(abs(network_range) / abs(point_range))

  for( points in plot$plotted$points) {
    dim_cols = colnames(points$data)[find_dimension_cols(points$data)]
    points$data[, c(dim_cols) := lapply(.SD, function(x) x * scale_factor), .SDcols = c(dim_cols)]
    more_args = list()
    more_args$enaplot <- plot
    more_args$points <- points$data
    more_args$colors <- points$color
    plot <- do.call(ena.plot.points, more_args)
  }
  for(means in plot$plotted$means) {
    more_args <- list()
    more_args$enaplot <- plot
    more_args$points <- means$data * scale_factor
    more_args$colors <- means$color
    plot <- do.call(ena.plot.group, more_args)
  }

  set$plots[[length(set$plots)]] <- plot

  invisible(set)
}

#' Updates the axis ranges of an ENA plot based on the plotted data.
#'
#' This function adjusts the x and y axis ranges of the ENA plot to ensure that all plotted points, networks, and means are visible.
#'
#' @param x An ENA plot object containing the plotted data and axis configurations.
#'
#' @return The updated ENA plot object with adjusted axis ranges.
#'
#' @export
check_range <- function(x) {
  numbers <- as.numeric(sapply(x$plotted$points, function(p) max(as.matrix(p$data))));
  means <- as.numeric(sapply(x$plotted$means, function(p) max(as.matrix(p$data))));

  network <- NULL;
  if(length(x$plotted$networks) > 0) {
    network <- abs(as.numeric(sapply(x$plotted$networks, function(nn) sapply(nn, `[`, c("x0","x1","y0","y1")))));
  }

  if(
    length(numbers) == 0 &&
    length(means) == 0
  ) {
    return(x)
  }

  curr_max = max(c(numbers, network, means))
  if(curr_max*1.2 > max(x$axes$y$range)) {
    this.max = curr_max * 1.2
    x$axes$x$range = c(-this.max, this.max)
    x$axes$y$range = c(-this.max, this.max)
    x$plot = plotly::layout(
      x$plot,
      xaxis = x$axes$x,
      yaxis = x$axes$y
    );
  } else if (curr_max < max(x$axes$y$range*0.5)) {
    this.max = curr_max * 1.2
    x$axes$x$range = c(-this.max, this.max)
    x$axes$y$range = c(-this.max, this.max)
    x$plot = plotly::layout(
      x$plot,
      xaxis = x$axes$x,
      yaxis = x$axes$y
    );
  }

  x
}

#' Display and update plot objects within a custom object
#'
#' This function updates the plots within the provided object by applying the `check_range` function to each plot.
#' It then prints the updated object using custom print options and returns the object invisibly.
#'
#' @param x An object containing a list of plots in the `plots` field.
#' @param ... Additional arguments passed to the `print` method.
#'
#' @return The updated object `x`, returned invisibly.
#'
#' @export
show <- function(x, ...) {
  x$plots <- lapply(x$plots, check_range)
  print(x, ..., plot = T, set = F)
  invisible(x)
}
