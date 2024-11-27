#' Title
#'
#' @param data data.frame
#' @param units character vector
#' @param conversation character vector
#' @param codes character vector
#' @param ... arguments passed along to other functions
#'
#' @return ena object
#' @export
#'
#' @examples
#' data(RS.data)
#'
#' codes = c('Data','Technical.Constraints','Performance.Parameters','Client.and.Consultant.Requests','Design.Reasoning','Collaboration');
#' units = c("Condition", "UserName");
#' conversation = c("Condition","GroupName");
#'
#' enaset <- RS.data |>
#'   accumulate(units, conversation, codes)
#'
accumulate <- function(
  x,
  units = qedata::units(x),
  codes = qedata::codes(x),
  horizon = qedata::horizon(x),
  ...
) {
  set <- ena.accumulate.data.file(
    file = x,
    units.by = units,
    conversations.by = horizon,
    codes = codes,
    ...
  )

  set$rotation <- list(
    rotation.matrix = NULL,
    codes = codes,
    node.positions = NULL,
    eigenvalues = NULL,
    centervec = NULL
  );

  return(set);
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
unit_cols <- function(
  x, ...
) {
  if(!qedata::is.qe.data(x)) {
    x <- qedata::as.qe.data(x);
  }

  wh <- list(...);
  return(qedata::units(x, wh));
}



#' Title
#'
#' @param data result of accumulate
#' @param ... arguments passed along to other functions
#'
#' @return ena object
#' @export
#'
#' @examples
#' data(RS.data)
#'
#' codes = c('Data','Technical.Constraints','Performance.Parameters','Client.and.Consultant.Requests','Design.Reasoning','Collaboration');
#' units = c("Condition", "UserName");
#' conversation = c("Condition","GroupName");
#'
#' enaset <- RS.data |>
#'   accumulate(units, conversation, codes) |>
#'   model()
#'
model <- function(
  data, ...,
  normalize = rENA::sphere_norm,
  center = rENA::center,
  rotate = rENA::rotate,
  project = rENA::project,
  optimize = rENA::optimize,

  # Rotation specific parameters
  rotate_fun = rENA::ena.svd, rotate_params = list()
) {
  x <- normalize(data);
  x <- center(x);

  if(length(rotate_params) > 0) {
    x <- do.call(rotate, list(x, unlist(rotate_params)));
  }
  else {
    x <- rotate(x);
  }

  x <- project(x);

  if(!is.null(optimize) && !isFALSE(optimize)) {
    x <- optimize(x);
  }

  return(x);
}



#' sphere norm
#'
#' @param x ena.set or matrix of connection counts
#'
#' @return ena.set
#' @export
#'
#' @examples
sphere_norm <- function(x, add.meta = TRUE) {
  x_ <- NULL;
  names_ <- NULL;
  meta_ <- NULL;

  if(is(x, "ena.set")) {
    x_ <- x$connection.counts;
    names_ <- svector_to_ut(x$rotation$codes);
    if(isTRUE(add.meta)) {
      meta_ <- x$meta.data;
    }
  }
  else {
    x_ <- x;
    names_ <- colnames(as.matrix(x));
  }

  x$line.weights <- fun_sphere_norm(as.matrix(x_));
  colnames(x$line.weights) <- names_;

  x$line.weights <- as_line_weights_matrix(x$line.weights, meta_);
  x$rotation$centervec <- colMeans(x$line.weights);

  return(x);
}


as_points_matrix <- function(x, metadata = NULL) {
  x_ <- data.table::as.data.table(x)
  for (i in seq(ncol(x_)))
    set(x_, j = i,
        value = as.ena.co.occurrence(x_[[i]]))

  if(!is.null(metadata)) {
    x_ <- cbind(metadata, x_);
  }

  class(x_) <- c("ena.points", "ena.matrix", class(x_));

  return(x_);
}

as_line_weights_matrix <- function(x, metadata = NULL) {
  line.weights.dt <- data.table::as.data.table(x)
  for (i in seq(ncol(line.weights.dt)))
    set(line.weights.dt, j = i,
        value = as.ena.co.occurrence(line.weights.dt[[i]]))

  x_ <- line.weights.dt;
  if(!is.null(metadata)) {
    x_ <- cbind(metadata, line.weights.dt);
  }

  class(x_) <- c("ena.line.weights", "ena.matrix", class(line.weights.dt));

  return(x_);
}

as_rotation_matrix <- function(x) {
  x_ <- data.table::as.data.table(x, keep.rownames = "codes");
  for (i in seq(ncol(x_))) {
    if(i == 1) {
      set(x_, j = i, value = as.ena.metadata(x_[[i]])
      )
    }
    else {
      set(x_, j = i, value = as.ena.dimension(x_[[i]]))
    }
  }
  class(x_) <- c("ena.rotation.matrix", class(x_));

  return(x_);
}

as_nodes_matrix <- function(x, rows, cols = NULL, cls = "ena.matrix") {
  x_ <- data.table::data.table(rows[[1]], x);
  rownames(x_) <- rows[[1]];

  if(!is.null(cols)) {
    colnames(x_) <- c(names(rows), cols);
  }

  for (i in seq(ncol(x_))) {
    if(i == 1) {
      set(x_, j = i, value = as.ena.metadata(x_[[i]]))
    }
    else {
      set(x_, j = i, value = as.ena.dimension(x_[[i]]))
    }
  }

  class(x_) = c(cls, class(x_));

  return(x_);
}

#' Title
#'
#' @param x
#' @param add.meta
#'
#' @return
#' @export
#'
#' @examples
center <- function(x, add.meta = TRUE) {
  x_ <- NULL;
  names_ <- NULL;
  meta_ <- NULL;

  if(is(x, "ena.set")) {
    x_ <- x$line.weights;
    names_ <- svector_to_ut(x$rotation$codes);
    if(isTRUE(add.meta)) {
      meta_ <- x$meta.data;
    }
  }
  else {
    x_ <- x;
    names_ <- colnames(as.matrix(x_));
  }

  x$model$points.for.projection <- center_data_c(as.matrix(x_));
  colnames(x$model$points.for.projection) <- names_;

  x$model$points.for.projection <- as_points_matrix(x$model$points.for.projection, meta_);

  return(x);
}

#' Title
#'
#' @param x
#' @param add.meta
#'
#' @return
#' @export
#'
#' @examples
rotate <- function(
  x, ...,
  by = NULL, wh = ena.svd, add.meta = TRUE
) {

  x_ <- NULL;
  names_ <- NULL;
  codes_ <- NULL;
  meta_ <- NULL;

  if(is(x, "ena.set")) {
    x_ <- x$line.weights;
    codes_ <- x$rotation$codes;
    names_ <- svector_to_ut(codes_);

    if(isTRUE(add.meta)) {
      meta_ <- x$meta.data;
    }
  }
  else {
    stop("Rotate by matrix alone is not implemented.");
    # x_ <- x;
    # browser();
    # # Need codes from the matrix!
    # names_ <- colnames(as.matrix(x_));
  }

  by_vals <- NULL;

  dot_args = list(...);
  if(length(dot_args) == 0) {
    wh = ena.svd
  }
  else {
    dot_formulas <- sapply(dot_args, function(d) {
      d2 <- tryCatch({ d3 = as.formula(d); TRUE }, error = function(e) FALSE)
      return(d2);
    });
    if(any(dot_formulas)) {
      if(all(dot_formulas)) {
        wh <- ena.rotate.by.hena.regression_2;
        by_vals <- list(params = dot_args);
        names(by_vals$params) <- c("x_var", "y_var")[seq_along(by_vals)];
      }
      else {
        stop("If rotating using a formula, all must be formulas")
      }
    }
    else {
      # Means rotation?
      browser()
    }
  }

  # if(!is.null(dot_args$rotate_params)) {
  #   by_vals <- list(params = dot_args$rotate_params);
  # }
  # else {
  #   if(!is.null(by)) {
  #
  #
  #     by_vals <- lapply(unique(x_[[by]]), `==`, x_[[by]]);
  #   }
  # }
  x$rotation <- do.call(wh, c(list(enaset = x), by_vals)); #, as_object = FALSE));
  x$rotation <- sapply(c("eigenvalues", "codes", "node.positions", "rotation"), function(y) x$rotation[[y]]);

  x$rotation.matrix <- as_rotation_matrix(x$rotation$rotation);
  x$rotation$rotation.matrix <- x$rotation.matrix;
  x$rotation$rotation <- NULL;

  return(x);
}

#' Title
#'
#' @param x
#' @param add.meta
#'
#' @return
#' @export
#'
#' @examples
project <- function(x, add.meta = TRUE) {
  meta_ <- NULL;

  points <- as.matrix(x$model$points.for.projection) %*% as.matrix(x$rotation.matrix);

  if(isTRUE(add.meta)) {
    meta_ <- x$meta.data;
  }
  x$points <- as_points_matrix(points, meta_);

  return(x);
}


#' Title
#'
#' @param x
#'
#' @return
#' @export
#'
#' @examples
optimize <- function(x) {
  positions <- lws.positions.sq(x);

  x$rotation$nodes <- as_nodes_matrix(positions$node.positions, list("code" = x$rotation$codes), cols = colnames(as.matrix(x$points)), cls = "ena.nodes");
  x$model$centroids <- as_nodes_matrix(positions$centroids, rows = list("ENA_UNIT" = x$points$ENA_UNIT), cols = colnames(as.matrix(x$points)));

  return(x);
}
