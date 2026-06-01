#' @title ENA Rotate by SVD (Principal Components)
#'
#' @description Performs a standard SVD (principal components) rotation on the
#'   ENA points. This is the rotation method used by default in Ordered Network
#'   Analysis (ONA). Unlike the generalized means rotation, no group labels are
#'   required.
#'
#' @param enaset An \code{\link{ENAset}} or compatible list with a
#'   \code{model$points.for.projection} matrix.
#' @param params A list of additional parameters (currently unused; kept for
#'   interface compatibility with other rotation functions).
#'
#' @return A list with:
#'   \describe{
#'     \item{rotation}{Rotation matrix (connection columns × dimensions),
#'       with columns named \code{SVD1}, \code{SVD2}, …}
#'     \item{codes}{Character vector of code names}
#'     \item{eigenvalues}{Variance explained per component}
#'     \item{node.positions}{NULL (not computed here)}
#'   }
#'
#' @export
ena.rotate.by.svd <- function(enaset, params = list()) {
  pts <- as.matrix(enaset$model$points.for.projection)

  pca <- prcomp(pts, retx = FALSE, scale. = FALSE, center = FALSE, tol = 0)

  colnames(pca$rotation) <- paste0("SVD", seq_len(ncol(pca$rotation)))

  list(
    rotation       = pca$rotation,
    codes          = enaset$rotation$codes,
    eigenvalues    = pca$sdev ^ 2,
    node.positions = NULL
  )
}
