#' Compute Between-Group Scatter Matrix
#'
#' This function calculates the between-group scatter matrix (\code{SB}) for a given numeric matrix and grouping variable.
#'
#' @param A A numeric matrix of dimensions \code{m x n}, where rows represent observations and columns represent features.
#' @param g A grouping variable of length \code{m}, either a factor or a character vector, indicating group membership for each observation.
#'
#' @return A numeric matrix representing the between-group scatter matrix (\code{SB}).
#'
#' @details
#' The function computes the total mean of the matrix \code{A} and the mean for each group defined by \code{g}.
#' It then calculates the between-group scatter matrix by summing the outer product of the mean differences, weighted by the group sizes.
#'
#' @examples
#' # Example usage:
#' A <- matrix(rnorm(20), nrow = 5, ncol = 4)
#' g <- factor(c("A", "B", "A", "B", "A"))
#' SB <- rENA:::compute_SB(A, g)
compute_SB <- function(A, g) {
  if (!is.matrix(A)) stop("A must be a numeric matrix.")
  if (length(g) != nrow(A)) stop("g must have the same length as number of rows in A.")

  g <- as.factor(g);
  groups <- levels(g);
  n_features <- ncol(A);
  m <- nrow(A);

  # Total mean
  mu_total <- colMeans(A);

  # Initialize matrices
  SB <- matrix(0, n_features, n_features);

  for (grp in groups) {
    idx <- which(g == grp);
    A_grp <- A[idx, , drop = FALSE];
    n_g <- nrow(A_grp);
    mu_g <- colMeans(A_grp);

    # Between-group component
    mean_diff <- matrix(mu_g - mu_total, ncol = 1);
    SB <- SB + n_g * (mean_diff %*% t(mean_diff));
  }

  return(SB);
}


#' Generalized Means Rotation (GMR) with optional subsetting and interaction control
#'
#' Computes a rotation (direction) `r` representing the contribution of the
#' first column of `X` to the multivariate ENA matrix `V`. Supports optional
#' subsetting by `groups`, optional inclusion of interaction terms when
#' computing adjusted contributions.
#'
#' @param V Numeric ENA matrix (units x connections) ready for rotation.
#' @param X Data frame or matrix of predictors; the first column is the target.
#' @param groups Optional vector specifying target groups to subset. If `NULL`
#'   (default), all rows are used.
#' @param alpha Elastic-net mixing parameter forwarded to `get_x1_main_effect`
#'   (default `1` - Lasso).
#' @param lambda Lambda selection for `cv.glmnet` forwarded to
#'   `get_x1_main_effect` (default `"lambda.min"`).
#' @param interactions Logical; if `TRUE` (default) interactions are included when computing the adjusted contribution.
#' @param verbose Logical; if `TRUE` (default) the function emits messages about
#'   fails or successes.
#'
#' @return A numeric vector `r` (length = ncol(V)) giving the normalized
#'   rotation direction. Attributes attached:
#'   \describe{
#'     \item{`target`}{The full-length target vector (un-subsetted).}
#'     \item{`Vx1`}{The unadjusted fitted values (`lm(V ~ target)`) embedded in
#'         a full-length matrix (rows outside subset filled with zeros).}
#'   }
#'   If no valid direction can be found (including SVD failure), returns `NULL`
#'   and issues a warning.
#'
#' @examples
#' \dontrun{
#' set.seed(1)
#' V <- matrix(rnorm(200), nrow = 40)
#' X <- data.frame(group = rep(letters[1:4], each = 10),
#'                 x2 = rnorm(40), x3 = rnorm(40))
#' r_all <- gmr2(V, X)
#' r_subset <- gmr2(V, X, groups = c("a", "b"), interactions = TRUE)
#' }
#'
#' @seealso [get_x1_main_effect()]
#' @importFrom stats lm model.matrix
#' @importFrom glmnet cv.glmnet
#' @export

gmr <- function(V, X, groups = NULL, alpha = 1, lambda = "lambda.min",
  interactions = TRUE, verbose = TRUE) {
  # prepare a function for almost zero check
  is_zero <- function(x, tol = 1e-12) all(abs(x) < tol)
  # get full target variable, namely, the first variable in X
  target_full <- X[[1]]
  if (is.list(target_full)) target_full <- unlist(target_full, recursive = FALSE)
  target_full <- as.vector(target_full)

  # --- Fail if target is constant ---
  unique_targets <- unique(target_full)
  if (length(unique_targets) == 1) {
    warning("Target variable is constant; returning NULL.")
    return(NULL)
  }

  # --- Subset by groups if selected groups are provided ---
  if (!is.null(groups)) {
    valid_groups <- intersect(groups, unique(target_full))
    if (length(valid_groups) > 1) {
      subset_idx <- which(target_full %in% valid_groups)
      V_sub <- V[subset_idx, , drop = FALSE]
      X_sub <- X[subset_idx, , drop = FALSE]
      target_sub <- target_full[subset_idx]
    } else {
      warning("Less than 2 valid groups selected; returning NULL.")
      return(NULL)
    }
  } else { # use full data if no groups are selected
    V_sub <- V
    X_sub <- X
    target_sub <- target_full
    subset_idx <- NULL
  }

  # --- Base regression model ---
  model <- lm(V_sub ~ target_sub)
  Vx1_sub <- model$fitted.values

  # --- Compute contributions via Lasso (if covariates exist) ---
  Vx_sub <- NULL
  if (ncol(X_sub) == 1) { # no corariates, use base model
    Vx_sub <- Vx1_sub
  } else { # covariates exist, use Lasso model
    Vx_sub <- get_x1_main_effect(V_sub, X_sub, alpha = alpha,
                                 lambda = lambda, include_interactions = interactions)
  }
  if (is_zero(Vx_sub)) {
    warning("Regression resulted in zeor contribution; returning NULL.")
    return(NULL)
  }
  # --- Compute rotation direction r ---
  r <- NULL
  if (is.numeric(target_sub)) {
    if (verbose) message("Computing direction for numeric target...")
    model =  model <- lm(Vx_sub ~ target_sub)
    beta <- model$coefficients[2,]
    if (is_zero(beta)) {
      warning("Numerical target with zero beta; returning NULL.")
      return(NULL)
    } else {
      r <- beta
    }
  } else {
    if (verbose) message("Computing direction for categorical target...")
    sb <- compute_SB(Vx_sub, target_sub)
    r <- tryCatch(svd(sb)$v[, 1], error = function(e) NULL)
  }

  # --- Final SVD fallback if r is NULL or zero ---
  if (is.null(r) || all(r == 0)) {
    warning("Uable to compute any valid direction; returning NULL.")
    return(NULL)
  }

  # --- Normalize ---
  r <- r / sqrt(sum(r^2))

  # --- Build full-length Vx1 ---
  Vx1_full <- matrix(0, nrow = nrow(V), ncol = ncol(V))
  Vx1_full[subset_idx %||% seq_len(nrow(V)), ] <- Vx_sub
  colnames(Vx1_full) <- colnames(V)

  # --- Attach metadata ---
  attr(r, "target") <- target_full
  attr(r, "Vx1") <- Vx1_full
  #attr(r, "fallback_stage") <- fallback_stage

  if (verbose) message(" gmr completed successfully ")
  return(r)
}

#' Extract the Main Effect of X on V with Optional Interactions
#'
#' Computes the main-effect contribution of the first column of `X` (the
#' "target") to the multivariate ENA matrix `V`. The function fits penalized
#' regression models (via glmnet) and can optionally include interactions
#' between the target and other covariates. It returns the fitted contribution
#' matrix (units x connections).
#'
#' The function can compute contributions using either only main-effect columns
#' (no interactions) or main-effect plus all interaction columns that start
#' with the target name. If no matching columns are found or all fitted
#' coefficients are zero, the function returns a zero matrix and emits a
#' warning.
#'
#' @param V A numeric matrix (units x connections) of dependent variables.
#' @param X A data frame or matrix of predictors / covariates. The **first**
#'   column is treated as the target variable whose contribution will be extracted.
#' @param alpha Elastic-net mixing parameter passed to `cv.glmnet`. `alpha = 1`
#'   (default) is Lasso; `alpha = 0` is ridge.
#' @param lambda Character or numeric. Which lambda from the `cv.glmnet` fit to
#'   use; e.g. `"lambda.min"` (default) or `"lambda.1se"`, or a numeric value.
#' @param include_interactions Logical; if `TRUE`, include main-effect columns
#'   **and** all interaction columns that begin with the target name (default:
#'   `FALSE`, only main-effect columns).
#'
#' @return A numeric matrix with the same dimensions as `V` containing the
#'   estimated contribution of `X[,1]` to each response. If no columns are
#'   matched or all coefficients are zero, a zero matrix is returned and a
#'   warning is issued.
#'
#' @details
#' Internally this function builds `model.matrix(~ .^2, data = X)` to obtain
#' main effects and pairwise interactions. It sets a `penalty.factor` that
#' leaves the target-related columns unpenalized (0) and fits a multivariate
#' `glmnet` (`family = "mgaussian"`). The returned matrix is dense (numeric).
#'
#' @examples
#' \dontrun{
#' set.seed(1)
#' V <- matrix(rnorm(50), ncol = 5)
#' X <- data.frame(CONFIDENCE = rnorm(10), Condition = factor(rep(1:2, 5)))
#' # main effects only
#' Vx_main <- get_x1_main_effect(V, X, include_interactions = FALSE)
#' # include interactions
#' Vx_full <- get_x1_main_effect(V, X, include_interactions = TRUE, alpha = 0) # ridge
#' }
#'
#' @seealso [gmr2()] for the rotation routine that uses this function.
#' @importFrom stats lm model.matrix
#' @importFrom glmnet cv.glmnet
#' @export

get_x1_main_effect <- function(V, X, alpha = 1, lambda = "lambda.min", include_interactions = FALSE) {
  x1_name <- colnames(X)[1]

  # 1. Formula & Model Matrix
  formula_str <- if (include_interactions) "~ .^2" else "~ ."
  mm <- model.matrix(as.formula(formula_str), data = X)[, -1, drop = FALSE]

  # 2. Identify Main Effect Columns for x1
  safe_x1 <- gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", x1_name)
  x1_main_regex <- paste0("^", safe_x1, "[^:]*$")
  x1_cols <- grep(x1_main_regex, colnames(mm))

  if (length(x1_cols) == 0) {
    warning("No main effect columns found for X[,1]; returning zeros.")
    return(matrix(0, nrow = nrow(V), ncol = ncol(V), dimnames = list(NULL, colnames(V))))
  }

  # 3. Penalty Factors
  p <- ncol(mm)
  penalty_factors <- rep(1, p)
  penalty_factors[x1_cols] <- 0

  # 4. Fitting Logic
  x1_contribution <- matrix(0, nrow = nrow(V), ncol = ncol(V), dimnames = list(NULL, colnames(V)))
  use_ols <- (p <= (nrow(X) - 10)) # Heuristic: Use OLS only if we have enough degrees of freedom

  if (!use_ols) {
    fit <- tryCatch(
      # We add lower.limits/upper.limits or tiny penalty to ensure x1 is NEVER zero if it has signal
      glmnet::cv.glmnet(x = mm, y = V, family = "mgaussian",
                        alpha = alpha, penalty.factor = penalty_factors),
      error = function(e) NULL
    )

    if (!is.null(fit)) {
      coefs_list <- coef(fit, s = lambda)
      # coefs_list is a list of sparse matrices (one per response)
      for (i in seq_along(coefs_list)) {
        # Extract coefs, skipping intercept ([1,])
        # Force to numeric to avoid sparse matrix indexing issues
        beta_all <- as.matrix(coefs_list[[i]])[-1, , drop = FALSE]
        beta_x1 <- beta_all[x1_cols, , drop = FALSE]
        x1_contribution[, i] <- mm[, x1_cols, drop = FALSE] %*% beta_x1
      }
      return(x1_contribution)
    }
    use_ols <- TRUE
  }

  if (use_ols) {
    fit_ols <- lm(V ~ mm)
    # as.matrix handles the 'incorrect number of dimensions' for single response
    beta_ols <- as.matrix(coef(fit_ols))[-1, , drop = FALSE]
    beta_x1_ols <- beta_ols[x1_cols, , drop = FALSE]

    # Handle NAs that OLS produces for rank-deficient matrices
    beta_x1_ols[is.na(beta_x1_ols)] <- 0
    x1_contribution <- mm[, x1_cols, drop = FALSE] %*% beta_x1_ols
  }

  return(x1_contribution)
}

