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
ena.rotate.by.generalized <- function(enaset, params) {

  safe_normalize <- function(vec, tol = 1e-12) {
    if (anyNA(vec) || sqrt(sum(vec^2)) < tol) return(NULL)
    vec / sqrt(sum(vec^2))
  }

  # Check x_var
  if (!is.list(params) || is.null(params$x_var)) stop("params must be a list() and provide `x_var`")
  x <- params$x_var
  if (!is.data.frame(x)) stop("x_var must be a data.frame")

  # Select V
  V <- if (is.null(enaset$points.normed.centered)) {
    as.matrix(enaset$model$points.for.projection)
  } else {
    as.matrix(enaset$points.normed.centered)
  }

  # gmr for x
  x_result <- if (!is.null(params$select_2_groups)) {
    gmr(V, x, groups = params$select_2_groups)
  } else gmr(V, x)

  if (is.null(x_result)) stop("gmr failed for x_vector")
  x_vector <- x_result
  Vx1 <- attr(x_result, "Vx1")
  target <- attr(x_result, "target")

  # Deflate matrix
  A <- V
  defA <- A - A %*% x_vector %*% t(x_vector)

  # Two-group adjustment
  x1 <- NULL
  if (!is.null(params$select_2_groups) && length(params$select_2_groups) == 2) {
    grp <- params$select_2_groups
    idx1 <- which(target == grp[[1]])
    idx2 <- which(target == grp[[2]])
    if (length(idx1) > 0 && length(idx2) > 0) {
      m1 <- colMeans(A[idx1, , drop = FALSE], na.rm = TRUE)
      m2 <- colMeans(A[idx2, , drop = FALSE], na.rm = TRUE)
      x1 <- safe_normalize(m1 - m2)
    }
  }

  # y_vector
  y_vector <- if (!is.null(params$y_var) && is.data.frame(params$y_var)) {
    gmr(defA, params$y_var)
  } else safe_normalize(svd(defA)$v[,1])

  if (is.null(y_vector)) stop("y_vector is NULL after fallback")
  #print(head(y_vector))
  # Orthogonalize y_vector
  y_vector <- y_vector - (t(y_vector) %*% x_vector) * x_vector
  #print(head(y_vector))
  if (!is.null(x1)) y_vector <- y_vector - (t(y_vector) %*% x1) * x1
  #print(head(y_vector))
  y_vector <- safe_normalize(y_vector)
  #print(head(y_vector))
  if (is.null(y_vector)) stop("y_vector became zero after orthogonalization")

  # Combine rotation
  R <- cbind(x_vector, y_vector)
  colnames(R) <- c("GMR1", if (!is.null(params$y_var)) "GMR2" else "SVD2")

  # Deflate and SVD for remaining
  defA <- A - A %*% x_vector %*% t(x_vector) - A %*% y_vector %*% t(y_vector)
  svd_v <- prcomp(defA, retx = FALSE, scale. = FALSE, center = FALSE, tol = 0)$rotation

  vcount <- ncol(R)
  combined <- cbind(R, svd_v[, 1:(ncol(svd_v) - vcount)])
  colnames(combined) <- c(colnames(R), paste0("SVD", ((vcount + 1):ncol(combined))))

  # Return rotation set
  rotation_set <- ENARotationSet$new(
    node.positions = NULL,
    rotation = combined,
    codes = enaset$rotation$codes,
    eigenvalues = NULL
  )

  return(rotation_set)
}


ena.rotate.by.generalized_bk_1 = function( enaset, params ) {

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
  if(!is.null(params$select_2_groups))
  {
    x_result<-gmr(V = V, X = x, groups = params$select_2_groups)
  }
  else {
    x_result <- gmr(V = V, X = x);
  }
  x_vector = x_result;
  Vx1 = attr(x_result,"Vx1"); # fitted values of regression in gmr
  target = attr(x_result,"target"); # target variable

  R <- matrix(c(x_vector), ncol = 1);
  colnames(R) <- c("GMR1");
  # deflate matrix by x dimension
  A <- as.matrix(V);
  defA <- A - A %*% x_vector %*% t(x_vector);

  # further deflate by the linear effect of target variable of x
  # the purpose is to put group means (two groups) back to the x-axis
  x1 <- NULL;
  if(!is.null(params$select_2_groups)) # deflate for two selected groups
  {
    grp = params$select_2_groups;
    if(length(grp)==2)
    {
      m1 <- colMeans(defA[target == grp[[1]], , drop = FALSE]);
      m2 <- colMeans(defA[target == grp[[2]], , drop = FALSE]);

      # Difference vector
      diff_vec <- m1 - m2;

      # Normalize if length is not near zero
      len <- sqrt(sum(diff_vec^2));
      if (len > 1e-10) {
        x1 <- diff_vec / len;
      }
    }
  }
  #if(is.null(x1)) # the case that 2 groups are not selected, remove the major contribution of the whole regression.
  #{
  #  x1 = svd(Vx1)$v[,1]; # the leading eigenvector of Vx1
  #}
  #orthogonalize x1 with x_vector
  #p = as.numeric(t(x1)%*%x_vector);
  #if(abs(p)<0.99) # in case x1 and x_vector are in the same direction
  #{
  #  x1 = x1 - p * x_vector;
    # re-normalize x1
  #  x1 <- x1 / sqrt(sum(x1^2));
    # deflate again
  #  defA <- defA - defA %*% x1 %*% t(x1); # this deflation should put the means back to x-axis (if the grouping variable is binary)
  #}
  y_vector <-NULL;
  y_name = "";
  # if y is given as a data.frame, gmr on y
  if (!is.null(params$y_var) && is.data.frame(params$y_var)) {
    y <- params$y_var;
    V <- defA;
    y_result <- gmr(V = defA, X = y);
    y_vector = y_result;
    y_name = "GMR2";

  }else
  {

    y_vector = svd(defA)$v[,1];
    y_name = "SVD2";
  }

  # make sure x_vector and y_vector are orthogonal
  y_vector<-y_vector-(t(y_vector) %*% x_vector) * x_vector;

  # equate two group means on y
  if(!is.null(x1)) # deflate for two selected groups
  {
    y_vector <- y_vector - (t(y_vector)%*%x1)*x1;
  }

  # re-normalize y
  y_vector <- y_vector / sqrt(sum(y_vector^2));

  R <- matrix(c(x_vector, y_vector), ncol = 2);

  colnames(R) <- c("GMR1", y_name);

  # now  deflation for x_vector and y_vector
  defA <- A - A %*% x_vector %*% t(x_vector) - A %*% y_vector %*% t(y_vector);

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

