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


  # check if x is a data.frame
  if (!is.data.frame(params$x_var)) {
    if(all(params$x_var %in% colnames(enaset$meta.data))) {
      x <- enaset$meta.data[, params$x_var, with = FALSE];
    } else {
      stop(paste("x_var incorrect: ", paste(params$x_var, collapse = ", ")));
    }
  }
  else {
    x <- params$x_var;
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
  colnames(R) <- c("RR1");
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

  if(is.null(x1)) {
    x1 = svd(Vx1)$v[,1]; # the leading eigenvector of Vx1
  }
  #orthogonalize x1 with x_vector
  p = as.numeric(t(x1)%*%x_vector);
  if(abs(p)<0.99) {
    x1 = x1 - p * x_vector;
    # re-normalize x1
  #  x1 <- x1 / sqrt(sum(x1^2));
    # deflate again
    defA <- defA - defA %*% x1 %*% t(x1); # this deflation should put the means back to x-axis (if the grouping variable is binary)
  }

  y_vector <-NULL;
  y_name = "";
  # if y is given as a data.frame, gmr on y
  if (!is.null(params$y_var)) {
    if(!is.data.frame(params$y_var)) {
      if(all(params$y_var %in% colnames(enaset$meta.data))) {
        params$y_var <- enaset$meta.data[, params$y_var, with = FALSE];
      }
      else {
        stop("y_var must be a data.frame or a column name in enaset$meta.data");
      }
    } 
    y <- params$y_var;
    V <- defA;
    y_result <- gmr(V = defA, X = y);
    y_vector = y_result;
    y_name = "RR2";
  }
  else {
    y_vector = svd(defA)$v[,1];
    y_name = "SVD2";
  }

  # re-normalize y
  y_vector <- y_vector / sqrt(sum(y_vector^2));

  R <- matrix(c(x_vector, y_vector), ncol = 2);

  colnames(R) <- c("RR1", y_name);

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
  rotation_set <- list(
    node.positions = NULL,
    rotation = combined,
    codes = enaset$rotation$codes,
    eigenvalues = NULL
  )
  return(rotation_set);
}

