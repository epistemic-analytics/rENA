#' Title
#'
#' @param x data.frame
#' @param units character vector
#' @param codes character vector
#' @param horizon character vector
#' @param ... arguments passed along to other functions
#' @param ordered logical defaults to FALSE for creating unordered networks
#'
#' @return ena object
#' @export
#'
#' @examples
#' data(RS.data)
#'
#' codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
#'            "Client.and.Consultant.Requests", "Design.Reasoning",
#'            "Collaboration")
#' units <- c("Condition", "UserName")
#' horizon <- c("Condition", "GroupName")
#' enaset <- RS.data |>
#'   accumulate(units, codes, horizon)
#'
accumulate <- function(
    x,
    units = units(x),
    codes = codes(x),
    horizon = horizon(x),
    ...,
    ordered = FALSE
) {
  # set <- ena.accumulate.data.file(
  #   file = x,
  #   units.by = units,
  #   conversations.by = horizon,
  #   codes = codes,
  #   ...
  # )
  args <- list(...)
  force(units);
  force(codes);
  force(horizon);

  hoo_rules <- list(
    str2lang(paste0("(", paste0(sapply(horizon, function(cb) paste0(cb, " %in% UNIT$", cb)), collapse = " & "), ")"))
  )
  contexts <- tma::contexts(
    x,
    units_by = make.names(units),
    hoo_rules = hoo_rules,
    split_rules = function(unit, unit_context) {
      split(unit_context, by = horizon)
    }
  )

  args$default_window <- if (is.null(args$default_window)) 1 else args$default_window
  args$default_weight <- if (is.null(args$default_weight)) 1 else args$default_weight
  win_wgts <- tma::context_tensor(
    df = x,
    sender_cols = args$tma_ground_cols,
    receiver_cols = args$tma_response_cols,
    mode_column = args$mode_column,
    ...
  )

  # args$ordered <- if (is.null(args$ordered)) TRUE else FALSE
  set <- tma::accumulate(
    context_model = contexts,
    # multidim_arr = multidim_arr,
    # time_column = args$time_column,
    codes = make.names(codes),
    ordered = ordered
  )

  set$rotation <- list(
    rotation.matrix = NULL,
    codes = codes,
    adjacency.key = sapply(colnames(as.matrix(set$connection.counts)), function(y) strsplit(y, "\\s?&\\s?")[[1]], simplify = T),
    node.positions = NULL,
    eigenvalues = NULL,
    centervec = NULL
  )

  return(set)
}

#' Reclassify specified columns as units in a data.table
#'
#' This function reclassifies specified columns of a data.table to the 'qe.unit' format.
#' If the input is not already of class 'qe.data', it is first converted to 'qe.data'.
#'
#' @param x A data.table. The data.table containing the columns to be reclassified.
#' @param ... Additional arguments specifying the names of the columns to be reclassified.
#'
#' @return The modified data.table with specified columns reclassified as 'qe.unit'.
#' @examples
#' library(data.table)
#' dt <- data.table(a = 1:5, b = 6:10)
#' dt <- units(dt, "a", "b")
#' @export
unit_cols <- function(x, ...) {
  if (!is.qe.data(x)) {
    x <- as.qe.data(x)
  }

  wh <- list(...)
  return(units(x, wh))
}



##' Build a Complete ENA Model
#'
#' This function applies a full ENA modeling pipeline to accumulated data, including normalization, centering, rotation, projection, and optional optimization.
#' Each step can be customized by supplying alternative functions. Additional rotation parameters can be passed via `rotate_params`.
#'
#' @param data An accumulated ENA data object (typically the result of `accumulate`).
#' @param ... Additional arguments passed to the rotation function.
#' @param normalize Function to use for normalization (default: `sphere_norm`).
#' @param center_with Function to use for centering (default: `center`).
#' @param rotate_with Function to use for rotation (default: `rotate`).
#' @param project_with Function to use for projection (default: `project`).
#' @param optimize_with Function to use for optimization (default: `optimize`).
#' @param rotate_fun Function to use for rotation (default: `ena.svd`).
#' @param rotate_params List of additional parameters to pass to the rotation function.
#'
#' @return An ENA set object with all modeling steps applied.
#' @export
#'
#' @examples
#' data(RS.data)
#'
#' codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
#'            "Client.and.Consultant.Requests", "Design.Reasoning",
#'            "Collaboration")
#' units <- c("Condition", "UserName")
#' horizon <- c("Condition", "GroupName")
#' enaset <- RS.data |>
#'   accumulate(units, codes, horizon) |>
#'   model()
model <- function(
  data, ...,
  normalize = sphere_norm,
  center_with = center,
  rotate_with = rotate,
  project_with = project,
  optimize_with = optimize,
  # Rotation specific parameters
  rotate_fun = ena.svd, 
  rotate_params = list()
) {
  x <- normalize(data)
  x <- center_with(x)

  if (length(rotate_params) > 0) {
    x <- do.call(rotate_with, list(x, wh = rotate_fun, by = unlist(rotate_params)))
  } else {
    x <- rotate_with(x, wh = rotate_fun, by = rotate_params)
  }

  x <- project_with(x)

  if (!is.null(optimize_with) && !isFALSE(optimize_with)) {
    x <- optimize_with(x)
  }

  return(x)
}

#' Apply Spherical Normalization to ENA Data
#'
#' This function applies spherical normalization to an ENA set or a matrix of connection counts.
#' It computes normalized line weights and updates the center vector of the rotation.
#'
#' @param x An \code{ena.set} object or a matrix of connection counts to be normalized.
#' @param add.meta Logical. If \code{TRUE} (default), metadata will be included in the output.
#'
#' @return The input \code{ena.set} object with normalized line weights and updated center vector.
#' @export
#'
#' @examples
#' # Assuming 'set' is an ena.set object:
#' data(RS.data)
#'
#' codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
#'            "Client.and.Consultant.Requests", "Design.Reasoning",
#'            "Collaboration")
#' units <- c("Condition", "UserName")
#' horizon <- c("Condition", "GroupName")
#' enaset <- RS.data |>
#'   accumulate(units, codes, horizon) |>
#'   sphere_norm()
sphere_norm <- function(x, add.meta = TRUE) {
  x_ <- NULL
  names_ <- NULL
  meta_ <- NULL

  if (is(x, "ena.set")) {
    x_ <- as.matrix(x$connection.counts)
    # names_ <- svector_to_ut(x$rotation$codes);
    # names_ <- apply(x$rotation$adjacency.key, 2, paste, collapse = " & ");
    names_ <- colnames(x_) # sapply(colnames(x_), function(y) strsplit(y, "\\s?&\\s?")[[1]], simplify = T);
    if (isTRUE(add.meta)) {
      meta_ <- x$meta.data
    }
  } else {
    x_ <- x
    names_ <- colnames(as.matrix(x))
  }

  x$line.weights <- fun_sphere_norm(as.matrix(x_))
  colnames(x$line.weights) <- names_

  x$line.weights <- as_line_weights_matrix(x$line.weights, meta_)
  x$rotation$centervec <- colMeans(x$line.weights)

  return(x)
}


as_points_matrix <- function(x, metadata = NULL) {
  x_ <- data.table::as.data.table(x)
  for (i in seq(ncol(x_))) {
    set(x_,
      j = i,
      value = as.ena.co.occurrence(x_[[i]])
    )
  }

  if (!is.null(metadata)) {
    x_ <- cbind(metadata, x_)
  }

  class(x_) <- c("ena.points", "ena.matrix", class(x_))

  return(x_)
}

as_line_weights_matrix <- function(x, metadata = NULL) {
  line.weights.dt <- data.table::as.data.table(x)
  for (i in seq(ncol(line.weights.dt))) {
    set(line.weights.dt,
      j = i,
      value = as.ena.co.occurrence(line.weights.dt[[i]])
    )
  }

  x_ <- line.weights.dt
  if (!is.null(metadata)) {
    x_ <- cbind(metadata, line.weights.dt)
  }

  class(x_) <- c("ena.line.weights", "ena.matrix", class(line.weights.dt))

  return(x_)
}

as_rotation_matrix <- function(x) {
  x_ <- data.table::as.data.table(x, keep.rownames = "codes")
  for (i in seq(ncol(x_))) {
    if (i == 1) {
      set(x_, j = i, value = as.ena.metadata(x_[[i]]))
    } else {
      set(x_, j = i, value = as.ena.dimension(x_[[i]]))
    }
  }
  class(x_) <- c("ena.rotation.matrix", class(x_))

  return(x_)
}

as_nodes_matrix <- function(x, rows, cols = NULL, cls = "ena.matrix") {
  x_ <- data.table::data.table(rows[[1]], x)
  rownames(x_) <- rows[[1]]

  if (!is.null(cols)) {
    colnames(x_) <- c(names(rows), cols)
  }

  for (i in seq(ncol(x_))) {
    if (i == 1) {
      set(x_, j = i, value = as.ena.metadata(x_[[i]]))
    } else {
      set(x_, j = i, value = as.ena.dimension(x_[[i]]))
    }
  }

  class(x_) <- c(cls, class(x_))

  return(x_)
}

##' Center ENA Data
#'
#' This function centers ENA data by subtracting the mean from each dimension of the line weights or input matrix.
#' The result is stored in the model's points for projection. Optionally, metadata can be included in the output.
#'
#' @param x An \code{ena.set} object or a matrix to be centered.
#' @param add.meta Logical. If \code{TRUE} (default), metadata will be included in the output.
#'
#' @return The input \code{ena.set} object with centered points for projection (and metadata if requested).
#' @export
#'
#' @examples
#' # Assuming 'set' is an ena.set object:
#' data(RS.data)
#'
#' codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
#'            "Client.and.Consultant.Requests", "Design.Reasoning",
#'            "Collaboration")
#' units <- c("Condition", "UserName")
#' horizon <- c("Condition", "GroupName")
#' enaset <- RS.data |>
#'   accumulate(units, codes, horizon) |>
#'   sphere_norm() |>
#'   center()
center <- function(x, add.meta = TRUE) {
  x_ <- NULL
  names_ <- NULL
  meta_ <- NULL

  if (is(x, "ena.set")) {
    # x_ <- x$line.weights;
    x_ <- as.matrix(x$line.weights)
    # names_ <- svector_to_ut(x$rotation$codes);
    names_ <- apply(x$rotation$adjacency.key, 2, paste, collapse = " & ")
    if (isTRUE(add.meta)) {
      meta_ <- x$meta.data
    }
  } else {
    x_ <- x
    names_ <- colnames(as.matrix(x_))
  }

  x$model$points.for.projection <- center_data_c(as.matrix(x_))
  colnames(x$model$points.for.projection) <- names_

  x$model$points.for.projection <- as_points_matrix(x$model$points.for.projection, meta_)

  return(x)
}

#' Rotate ENA Data
#'
#' Rotates ENA data using a specified rotation function (default: SVD), optionally using formulas or grouping variables.
#'
#' @param x An \code{ena.set} object to be rotated.
#' @param ... Optional formulas or additional arguments for rotation.
#' @param by Optional. A variable name or grouping variable for rotation.
#' @param wh Function to use for rotation (default: \code{ena.svd}).
#' @param add.meta Logical. If \code{TRUE} (default), metadata will be included in the output.
#'
#' @return The rotated \code{ena.set} object with updated rotation matrices.
#' @export
#'
#' @examples
#' # Assuming 'set' is an ena.set object:
#' data(RS.data)
#'
#' codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
#'            "Client.and.Consultant.Requests", "Design.Reasoning",
#'            "Collaboration")
#' units <- c("Condition", "UserName")
#' horizon <- c("Condition", "GroupName")
#' enaset <- RS.data |>
#'   accumulate(units, codes, horizon) |>
#'   sphere_norm() |>
#'   center() |>
#'   rotate()
rotate <- function(
  x, 
  ...,
  by = NULL, 
  wh = ena.svd, 
  add.meta = TRUE
) {
  x_ <- NULL
  names_ <- NULL
  codes_ <- NULL
  meta_ <- NULL

  if (is(x, "ena.set")) {
    x_ <- as.matrix(x$line.weights)
    codes_ <- as.matrix(x$rotation$codes)
    # names_ <- svector_to_ut(x$rotation$codes);
    names_ <- apply(x$rotation$adjacency.key, 2, paste, collapse = " & ")

    if (isTRUE(add.meta)) {
      meta_ <- x$meta.data
    }
  } else {
    stop("Rotate by matrix alone is not implemented.")
    # x_ <- x;
    # browser();
    # # Need codes from the matrix!
    # names_ <- colnames(as.matrix(x_));
  }

  by_vals <- NULL

  dot_args <- list(...)
  if (length(dot_args) == 0) {
    wh <- ena.svd
  } else {
    dot_formulas <- sapply(dot_args, function(d) {
      d2 <- tryCatch(
        {
          d3 <- as.formula(d)
          TRUE
        },
        error = function(e) FALSE
      )
      return(d2)
    })
    if (any(dot_formulas)) {
      if (all(dot_formulas)) {
        wh <- ena.rotate.by.hena.regression_2
        by_vals <- list(params = dot_args)
        names(by_vals$params) <- c("x_var", "y_var")[seq_along(by_vals)]
      } else {
        stop("If rotating using a formula, all must be formulas")
      }
    } else {
      # Means rotation?
      browser()
    }
  }

  # if(!is.null(dot_args$rotate_params)) {
  #   by_vals <- list(params = dot_args$rotate_params);
  # }
  x$rotation <- do.call(wh, c(list(enaset = x, as_object = FALSE), by_vals))
  # Ensure x$rotation is a list with required elements
  if (!is.list(x$rotation)) {
    stop("Rotation function did not return a list as expected.")
  }
  # Only extract elements that exist in the returned list
  rotation_elements <- c("eigenvalues", "codes", "node.positions", "rotation")
  x$rotation <- x$rotation[intersect(rotation_elements, names(x$rotation))]

  if (!is.null(x$rotation$rotation)) {
    x$rotation.matrix <- as_rotation_matrix(x$rotation$rotation)
    x$rotation$rotation.matrix <- x$rotation.matrix
    x$rotation$rotation <- NULL
  } else {
    x$rotation.matrix <- NULL
    x$rotation$rotation.matrix <- NULL
  }

  x$rotation.matrix <- as_rotation_matrix(x$rotation$rotation)
  x$rotation$rotation.matrix <- x$rotation.matrix
  x$rotation$rotation <- NULL

  return(x)
}

##' Project ENA Points onto Rotated Space
#'
#' This function projects ENA points onto the rotated space using the rotation matrix.
#' Optionally, metadata can be included in the resulting points matrix.
#'
#' @param x An \code{ena.set} object containing the points for projection and rotation matrix.
#' @param add.meta Logical. If \code{TRUE} (default), metadata will be included in the output.
#'
#' @return The input \code{ena.set} object with the projected points matrix (and metadata if requested).
#' @export
#'
#' @examples
#' # Assuming 'set' is an ena.set object:
#' data(RS.data)
#'
#' codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
#'            "Client.and.Consultant.Requests", "Design.Reasoning",
#'            "Collaboration")
#' units <- c("Condition", "UserName")
#' horizon <- c("Condition", "GroupName")
#' enaset <- RS.data |>
#'   accumulate(units, codes, horizon) |>
#'   sphere_norm() |>
#'   center() |>
#'   rotate() |>
#'   project()
project <- function(x, add.meta = TRUE) {
  meta_ <- NULL

  points <- as.matrix(x$model$points.for.projection) %*% as.matrix(x$rotation.matrix)

  if (isTRUE(add.meta)) {
    meta_ <- x$meta.data
  }
  x$points <- as_points_matrix(points, meta_)

  return(x)
}


##' Optimize Node and Centroid Positions in ENA Set
#'
#' This function computes and assigns node positions and centroids for an ENA set object
#' using the current points and rotation information.
#'
#' @param x An \code{ena.set} object for which to optimize node and centroid positions.
#'
#' @return The input \code{ena.set} object with updated node and centroid positions.
#' @export
#'
#' @examples
#' # Assuming 'set' is an ena.set object:
#' data(RS.data)
#'
#' codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
#'            "Client.and.Consultant.Requests", "Design.Reasoning",
#'            "Collaboration")
#' units <- c("Condition", "UserName")
#' horizon <- c("Condition", "GroupName")
#' enaset <- RS.data |>
#'   accumulate(units, codes, horizon) |>
#'   sphere_norm() |>
#'   center() |>
#'   rotate() |>
#'   project() |>
#'   optimize()
optimize <- function(x) {
  positions <- lws.positions.sq(x)

  x$rotation$nodes <- as_nodes_matrix(positions$node.positions, list("code" = x$rotation$codes), cols = colnames(as.matrix(x$points)), cls = "ena.nodes")
  x$model$centroids <- as_nodes_matrix(positions$centroids, rows = list("ENA_UNIT" = x$points$ENA_UNIT), cols = colnames(as.matrix(x$points)))

  return(x)
}
