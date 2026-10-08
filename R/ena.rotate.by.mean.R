###
#' @title ENA Rotate by mean
#'
#' @description Computes a dimensional reduction from a matrix of points such
#'   that the first dimension of the projected space passes through the means of
#'   two groups in the original space. Subsequent dimensions are computed using
#'   SVD on the deflated data. Computed in C++ by libena's \code{means_rotation}.
#'
#' @param enaset An \code{\link{ENAset}} or compatible list with
#'   \code{model$points.for.projection}, \code{connection.counts$ENA_UNIT},
#'   \code{line.weights}, and \code{rotation$codes}.
#' @param groups A list containing one or more pairs; each pair is a length-2
#'   list \code{list(a, b)} where \code{a} and \code{b} are either logical
#'   vectors (length = number of units) or character vectors of unit IDs.
#' @param params Alias for \code{groups}; used when called from the pipe API.
#'
#' @export
#' @return A list with \code{rotation}, \code{codes}, \code{eigenvalues}, and
#'   \code{node.positions = NULL}, suitable for use inside \code{rotate()}.
###
ena.rotate.by.mean <- function(enaset, groups = NULL, params = groups) {
  if (is.null(groups) && !is.null(params)) {
    groups <- params
  } else {
    groups <- list(groups)[[1]]
    if (length(groups) < 1) stop("Unable to rotate without 2 groups.")
  }
  if (!is(groups[[1]], "list")) groups <- list(groups)

  # Extract the data matrix (as.matrix strips metadata columns for ena.matrix)
  data <- if (!is.null(enaset$points.normed.centered)) {
    as.matrix(enaset$points.normed.centered)
  } else {
    as.matrix(enaset$model$points.for.projection)
  }

  # Convert groups (logical or character) to 0-based integer index pairs
  # required by means_rotation (libena)
  ena_unit <- enaset$connection.counts$ENA_UNIT
  group_pairs <- lapply(groups, function(pair) {
    a <- pair[[1]]
    b <- pair[[2]]
    if (!is.logical(a)) a <- ena_unit %in% a
    if (!is.logical(b)) b <- ena_unit %in% b
    list(as.integer(which(a) - 1L), as.integer(which(b) - 1L))
  })

  result <- means_rotation(data, group_pairs)

  rotation <- result$rotation
  colnames(rotation) <- result$column_names
  rownames(rotation) <- colnames(as.matrix(enaset$line.weights))

  list(
    node.positions = NULL,
    rotation       = rotation,
    codes          = enaset$rotation$codes,
    eigenvalues    = result$eigenvalues
  )
}
