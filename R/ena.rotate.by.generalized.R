###
#' @title ENA Rotate by generalized means rotation (gmr)
#'
#' @param enaset An \code{\link{ENAset}}
#' @param params list of parameters, may include:
#'     x_var: data.frame used for calling gmr() on the first dimension
#'     y_var: data.frame used for calling gmr() on the second dimension (optional).
#'
#' @export
#' @return \code{\link{ENARotationSet}}
ena.rotate.by.generalized = function( enaset, params ) {

  # check arguments
  if ( !is.list(params) || is.null(params$x_var) ) {
    stop("params must be provided as a list() and provide `x_var`")
  }

  # x should be a data.frame with colnames
  x <- params$x_var;


  # check if x is a data.frame
  if (!is.data.frame(x)) {
    stop("x_var must be a data.frame with column names");
  }

  if (is.null(enaset$points.normed.centered)) {
    V <- as.matrix(enaset$model$points.for.projection);
  }
  else {
    V <- as.matrix(enaset$points.normed.centered);
  }

  # call gmr
  # if x is a data.frame, we assume the first column is the target variable
  x_vector <- gmr(V = V, X = x);
  
  R <- matrix(c(x_vector), ncol = 1);
  colnames(R) <- c("GMR1");

  # #deflate matrix by x dimension
  A <- as.matrix(V);
  defA <- as.matrix(A) - as.matrix(A) %*% x_vector %*% t(x_vector);

  # old HENA y-dim code here
  # not sure how to handle this yet, so leaving it commented out

  # #if y formula is given, regress by y formula
  if (!is.null(params$y_var)) {
    y <- params$y_var;

    # regress to get v2 vector using formula y
    V <- defA;

    y_vector <- gmr(V = defA, X = y);
    R <- matrix(c(x_vector, y_vector), ncol = 2);
    colnames(R) <- c("GMR1", "GMR2");

    defA <- as.matrix(defA) - as.matrix(defA) %*% y_vector %*% t(y_vector);
  }

  # # get svd for deflated points
  svd_result <- prcomp(defA, retx=FALSE, scale=FALSE, center=FALSE, tol=0);
  svd_v <- svd_result$rotation;

  # Merge rotation vectors
  vcount <- ncol(R);
  colNamesR <- colnames(R);
  combined <- cbind(R, svd_v[, 1:(ncol(svd_v) - vcount)]);
  colnames(combined) <- c(
    colNamesR,
    paste0("SVD", ((vcount + 1):ncol(combined)))
  );

  #create rotation set
  rotation_set <- ENARotationSet$new(
    node.positions = NULL,
    rotation = combined,
    codes = enaset$rotation$codes,
    eigenvalues = NULL
  )

  return(rotation_set);
}

