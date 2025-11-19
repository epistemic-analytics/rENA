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
#' computing adjusted contributions, and robust multi-level fallbacks.
#'
#' Fallback / robustness layers:
#'
#' 1. If `groups` is specified but fewer than 2 valid groups exist, uses all rows.
#'
#' 2. If the target variable is constant, falls back to SVD of V.
#'
#' 3. If covariates exist, attempts Lasso (with or without interactions) to estimate
#'    contribution of the target; falls back to simple regression if all-zero.
#'
#' 4. If simple regression gives zero coefficients, falls back to SVD(V_sub).
#'
#' 5. For categorical targets, computes rotation from SVD of SB matrix.
#'
#' 6. Always normalizes the resulting vector and attaches metadata:
#'
#'    - target (original X[,1])
#'
#'    - Vx1 (full-length fitted values)
#'
#'    - fallback_stage (describes which fallback was used)
#'
#' This ensures that the function is robust to single-group selections,
#' constant targets, zero contributions, and categorical variables.
#'
#' The function attempts the following model sequence to estimate the target
#' contribution:
#'
#' (1) covariates + interactions (if requested),
#'
#' (2) covariates
#' only (no interactions),
#'
#' (3) no covariates (simple `lm`), and finally
#'
#' (4)SVD-based fallback on `V`.
#'
#' Warnings are emitted whenever a fallback step is
#' used. If SVD fails, `NULL` is returned with a warning.
#'
#' @param V Numeric ENA matrix (units × connections) ready for rotation.
#' @param X Data frame or matrix of predictors; the first column is the target.
#' @param groups Optional vector specifying target groups to subset. If `NULL`
#'   (default), all rows are used.
#' @param alpha Elastic-net mixing parameter forwarded to `get_x1_main_effect`
#'   (default `1` — Lasso).
#' @param lambda Lambda selection for `cv.glmnet` forwarded to
#'   `get_x1_main_effect` (default `"lambda.min"`).
#' @param interactions Logical; if `TRUE` (default) the first fallback attempts
#'   to include interactions when computing the adjusted contribution.
#' @param verbose Logical; if `TRUE` (default) the function emits messages about
#'   fallback stages and successes.
#'
#' @return A numeric vector `r` (length = ncol(V)) giving the normalized
#'   rotation direction. Attributes attached:
#'   \describe{
#'     \item{`target`}{The full-length target vector (un-subsetted).}
#'     \item{`Vx1`}{The unadjusted fitted values (`lm(V ~ target)`) embedded in
#'         a full-length matrix (rows outside subset filled with zeros).}
#'     \item{`fallback_stage`}{A short string describing which fallback was used.}
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

  target_full <- X[[1]]
  if (is.list(target_full)) target_full <- unlist(target_full, recursive = FALSE)
  target_full <- as.vector(target_full)

  # --- Early SVD fallback if target is constant ---
  unique_targets <- unique(target_full)
  if (length(unique_targets) == 1) {
    if (verbose) message("Target variable is constant; falling back to SVD(V)")
    r <- tryCatch(svd(V)$v[, 1], error = function(e) NULL)
    fallback_stage <- "constant target SVD"

    if (is.null(r)) {
      warning("Unable to compute any valid direction; returning NULL.")
      return(NULL)
    }

    r <- r / sqrt(sum(r^2))
    Vx1_full <- matrix(0, nrow = nrow(V), ncol = ncol(V))
    colnames(Vx1_full) <- colnames(V)

    attr(r, "target") <- target_full
    attr(r, "Vx1") <- Vx1_full
    attr(r, "fallback_stage") <- fallback_stage
    return(r)
  }

  # --- Subset by groups if provided ---
  if (!is.null(groups)) {
    valid_groups <- intersect(groups, unique(target_full))
    if (length(valid_groups) > 1) {
      subset_idx <- which(target_full %in% valid_groups)
      V_sub <- V[subset_idx, , drop = FALSE]
      X_sub <- X[subset_idx, , drop = FALSE]
      target_sub <- target_full[subset_idx]
    } else {
      if (verbose) message("Less than 2 valid groups selected; using all rows instead")
      V_sub <- V
      X_sub <- X
      target_sub <- target_full
      subset_idx <- NULL
    }
  } else {
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
  fallback_stage <- NULL

  if (ncol(X_sub) == 1) {
    Vx_sub <- Vx1_sub
    fallback_stage <- "no covariates"
  } else {
    Vx_sub <- get_x1_main_effect(V_sub, X_sub, alpha = alpha,
                                 lambda = lambda, include_interactions = interactions)
    if (all(Vx_sub == 0)) {
      if (verbose) message("⚠️ Lasso with interactions gave zero contribution; trying without interactions.")
      Vx_sub <- get_x1_main_effect(V_sub, X_sub, alpha = alpha,
                                   lambda = lambda, include_interactions = FALSE)
      fallback_stage <- "no interactions"
    } else {
      fallback_stage <- if (interactions) "with interactions" else "no interactions"
    }

    if (all(Vx_sub == 0)) {
      if (verbose) message("⚠️ Lasso without interactions gave zero contribution; falling back to simple model.")
      Vx_sub <- Vx1_sub
      fallback_stage <- "no covariates"
    }
  }

  # --- Compute rotation direction r ---
  if (is.numeric(target_sub)) {
    if (verbose) message("Computing direction for numeric target...")
    model =  model <- lm(Vx_sub ~ target_sub)
    beta <- coef(model)[2, ]
    if (all(beta == 0)) {
      if (verbose) message("⚠️ Beta is zero; falling back to SVD(V_sub).")
      r <- tryCatch(svd(Vx_sub)$v[, 1], error = function(e) NULL)
      fallback_stage <- "SVD fallback"
    } else {
      r <- beta / sqrt(sum(beta^2))
    }
  } else {
    if (verbose) message("Computing direction for categorical target...")
    sb <- compute_SB(Vx_sub, target_sub)
    r <- tryCatch(svd(sb)$v[, 1], error = function(e) NULL)
    fallback_stage <- "SVD of SB"
  }

  # --- Final SVD fallback if r is NULL or zero ---
  if (is.null(r) || all(r == 0)) {
    warning("⚠️ All levels failed; using SVD(V_sub)$v[,1] as final fallback.")
    r <- tryCatch(svd(V_sub)$v[, 1], error = function(e) NULL)
    fallback_stage <- "final SVD"
  }

  if (is.null(r)) {
    warning("❌ Unable to compute any valid direction; returning NULL.")
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
  attr(r, "fallback_stage") <- fallback_stage

  if (verbose) message("✅ gmr completed successfully (", fallback_stage, ").")

  return(r)
}


gmr_bk1 <- function(V,X) {
  # matrix, ENA set points for projection
  # data frame containing all predictor variables, first as target
  Vx <- NULL; # main effect of X1 adjusted for covariates
  r <- NULL; # return direction
  Vx1 <- NULL; # main effect of X1 without adjustment
  target <- X[[1]]          # always returns the column itself
  print(colnames(X)[1])
  if (is.list(target)) {    # flatten if it's a list-column
    target <- unlist(target, recursive = FALSE)
  }
  target <- as.vector(target)  # ensure atomic

  model <- lm(V ~ target)
  #model <- lm(V ~ X[, 1]); # simple linear model on X[1]
  Vx1 <- model$fitted.values;
  if(ncol(X)==1) { # simple linear model if there is no covariates
    Vx <- Vx1;
  }
  else { # Lasso model adjusted for covariates
    Vx <- get_x1_main_effect(V,X);
  }
  if (is.numeric(target)) { # compute direction for numerical variable
    # Reuse the coefficients from the initial model instead of rebuilding
    print("target is numeric")
    beta <- coef(model)[2,];  # Second coefficient is for the slope
    r <- beta / sqrt(sum(beta^2));
  }
  else {
    print("target is NOT numeric")
    sb <- compute_SB(Vx, target);

    r <- svd(sb)$v[, 1];

  }
  # project r to span of row vectors of V
  #model <- lm(r ~ t(V) + 0)
  #r<- Vx1 <- model$fitted.values;
  #r <- t(V) %*% coef(lm(r ~ t(V) + 0));    # Projection: r ~ V^T %*% beta
  #r <- r / sqrt(sum(r^2));
  attr(r, "target") <- target
  attr(r, "Vx1") <- Vx1# target contribution
  return(r);
}

gmr2_bk <- function(V, X, groups = NULL) {
  target_full <- X[[1]]
  if (is.list(target_full)) target_full <- unlist(target_full, recursive = FALSE)
  target_full <- as.vector(target_full)

  subset_idx <- NULL
  if (!is.null(groups)) {
    if (all(groups %in% unique(target_full))) {
      subset_idx <- which(target_full %in% groups)
      V_sub <- V[subset_idx, , drop = FALSE]
      X_sub <- X[subset_idx, , drop = FALSE]
      target_sub <- target_full[subset_idx]
    } else {
      warning("Specified groups not found; using all data.")
      V_sub <- V
      X_sub <- X
      target_sub <- target_full
    }
  } else {
    V_sub <- V
    X_sub <- X
    target_sub <- target_full
  }

  model <- lm(V_sub ~ target_sub)
  Vx1_sub <- model$fitted.values

  if (ncol(X_sub) == 1) {
    Vx_sub <- Vx1_sub
  } else {
    Vx_sub <- get_x1_main_effect(V_sub, X_sub)
  }

  if (is.numeric(target_sub)) {
    beta <- coef(model)[2, ]
    r <- beta / sqrt(sum(beta^2))
  } else {
    sb <- compute_SB(Vx_sub, target_sub)
    r <- svd(sb)$v[, 1]
  }

  # Build full Vx1: fill subset rows, zeros elsewhere
  Vx1_full <- matrix(0, nrow = nrow(V), ncol = ncol(V))
  Vx1_full[subset_idx %||% seq_len(nrow(V)), ] <- Vx1_sub
  colnames(Vx1_full) <- colnames(V)

  attr(r, "target") <- target_full
  attr(r, "Vx1") <- Vx1_full
  return(r)
}

#' Extract the Main Effect of X on V with Optional Interactions
#'
#' Computes the main-effect contribution of the first column of `X` (the
#' "target") to the multivariate ENA matrix `V`. The function fits penalized
#' regression models (via glmnet) and can optionally include interactions
#' between the target and other covariates. It returns the fitted contribution
#' matrix (units × connections).
#'
#' The function can compute contributions using either only main-effect columns
#' (no interactions) or main-effect plus all interaction columns that start
#' with the target name. If no matching columns are found or all fitted
#' coefficients are zero, the function returns a zero matrix and emits a
#' warning.
#'
#' @param V A numeric matrix (units × connections) of dependent variables.
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
#' @param ... Additional arguments are not used (kept for forward compatibility).
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
  # first column of X is the target variable
  x1_name <- colnames(X)[1]

  # Create model matrix (handles factors)
  mm <- model.matrix(~ .^2, data = X)

  # Escape special regex characters in x1_name
  safe_x1 <- gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", x1_name)

  # Select columns for x1
  if (include_interactions) {
    # include main effect + all interactions starting with x1
    x1_cols <- grep(paste0("^", safe_x1), colnames(mm))
  } else {
    # only main effect (no colon)
    x1_cols <- grep(paste0("^", safe_x1, "$|^", safe_x1, "(?=[^:])"), colnames(mm), perl = TRUE)
  }

  if (length(x1_cols) == 0) {
    warning("No columns found for X[,1]; returning zeros.")
    return(matrix(0, nrow = nrow(V), ncol = ncol(V), dimnames = list(NULL, colnames(V))))
  }

  # Penalty factors: 0 for x1 columns to force inclusion
  penalty.factor <- rep(1, ncol(mm))
  penalty.factor[x1_cols] <- 0

  # Determine if fallback to OLS is needed
  use_ols <- FALSE
  if (all(penalty.factor[-1] == 0)) {  # only intercept + x1 columns
    use_ols <- TRUE
  }

  # Fit Lasso (multi-response) or fallback to OLS
  if (!use_ols) {
    fit <- tryCatch(
      cv.glmnet(x = mm, y = V, family = "mgaussian", alpha = alpha, penalty.factor = penalty.factor),
      error = function(e) NULL
    )
    if (is.null(fit)) use_ols <- TRUE
  }

  # Preallocate contribution matrix
  x1_contribution <- matrix(0, nrow = nrow(V), ncol = ncol(V))
  colnames(x1_contribution) <- colnames(V)

  if (use_ols) {
    # fallback to OLS (handles multi-response)
    for (i in seq_len(ncol(V))) {
      fit_lm <- lm(V[, i] ~ mm[, x1_cols, drop = FALSE])
      x1_contribution[, i] <- predict(fit_lm, newdata = as.data.frame(mm))
    }
  } else {
    # Lasso case
    coefs_list <- coef(fit, s = lambda)
    for (i in seq_along(coefs_list)) {
      coef_vec <- as.numeric(coefs_list[[i]][x1_cols, , drop = FALSE])
      if (!all(is.na(coef_vec)) && !all(coef_vec == 0)) {
        x1_contribution[, i] <- mm[, x1_cols, drop = FALSE] %*% coef_vec
      }
    }
  }

  return(x1_contribution)
}




get_x1_main_effect_bk <- function(V, X, alpha = 1, lambda = "lambda.min") {
  # assume the first variable is the target variable
  x1_name <- colnames(X)[1]
  # print(x1_name)

  # Create model matrix (handles factors correctly)
  mm <- model.matrix(~ .^2, data = X)

  # Escape special regex chars in variable name (robust)
  safe_x1 <- gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", x1_name)

  # Match all main-effect columns for x1 (exclude interactions which contain ':')
  x1_cols <- grep(paste0("^", safe_x1, "[^:]*$"), colnames(mm))
  # If no match, return zeros immediately
  if (length(x1_cols) == 0) {
    warning("No main-effect columns found for x1; returning zeros.")
    return(matrix(0, nrow = nrow(V), ncol = ncol(V), dimnames = list(NULL, colnames(V))))
  }

  # Create penalty factors (0 for x1 terms to force inclusion, 1 for others)
  penalty.factor <- rep(1, ncol(mm))
  penalty.factor[x1_cols] <- 0

  # Fit penalized multivariate model
  fit <- cv.glmnet(x = mm, y = V, family = "mgaussian", alpha = alpha, penalty.factor = penalty.factor)
  coefs_list <- coef(fit, s = lambda)  # list of coefficient objects (one per response)

  print("colnames(mm)[x1_cols]")
  print(colnames(mm)[x1_cols])
  print("as.numeric(coefs_list[[1]][x1_cols, , drop=FALSE])")
  print(as.numeric(coefs_list[[1]][x1_cols, , drop=FALSE]))   # example coef vector
  print("as.matrix(mm[, x1_cols, drop = FALSE]) %*% as.numeric(coefs_list[[1]][x1_cols, , drop=FALSE])")
  print(head(as.matrix(mm[, x1_cols, drop = FALSE]) %*% as.numeric(coefs_list[[1]][x1_cols, , drop=FALSE])))

  # Prepare output
  x1_contribution <- matrix(NA, nrow = nrow(V), ncol = ncol(V))
  colnames(x1_contribution) <- colnames(V)

  # Pre-extract the design block as dense matrix once
  mm_x1 <- as.matrix(mm[, x1_cols, drop = FALSE])

  for (i in seq_along(coefs_list)) {
    coef_mat <- coefs_list[[i]]                 # typically a dgCMatrix with rownames
    # extract rows corresponding to x1_cols and coerce to numeric vector
    beta_part <- as.numeric(coef_mat[x1_cols, , drop = FALSE])
    # If the coefficient vector is all NA (unlikely) or length mismatch, handle gracefully
    if (length(beta_part) != ncol(mm_x1)) {
      # This is a safety fallback: try to match by rownames
      rn <- rownames(coef_mat)
      matched <- match(colnames(mm_x1), rn)
      if (all(!is.na(matched))) {
        beta_part <- as.numeric(coef_mat[matched, , drop = FALSE])
      } else {
        stop("Coefficient extraction failed: length mismatch and rowname matching failed.")
      }
    }
    # Compute contribution (dense numeric multiplication)
    temp_result <- mm_x1 %*% beta_part
    x1_contribution[, i] <- as.vector(temp_result)
  }

  return(x1_contribution)
}

get_x1_main_effect_copy <- function(V, X, alpha = 1, lambda = "lambda.min") {
  # assume the first variable is the target variable
  x1_name <- colnames(X)[1];
  print(x1_name)

  # Create model matrix (handles factors correctly)
  mm <- model.matrix(~ .^2, data = X);
 # print("colnames(mm):")
#  print(colnames(mm))

  # Escape special regex chars in variable name
  safe_x1 <- gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", x1_name)
 # print("safe_x1:")
#  print(safe_x1)

  # Match all main-effect columns for x1 (exclude interactions)
 # print("x1_cols new:")
  x1_cols <- grep(paste0("^", safe_x1, "[^:]*$"), colnames(mm))
  #print(x1_cols)
  # This pattern matches x1_name at the start of the string, not followed by a colon
  #x1_cols <- grep(paste0("^", x1_name, "$|^", x1_name, "(?=[^:])"), colnames(mm), perl = TRUE);
  #print("x1_cols old:")
  #print(x1_cols)

  # Create penalty factors (0 for x1 terms to force inclusion, 1 for others)
  penalty.factor <- rep(1, ncol(mm));

  # Don't penalize x1 terms
  penalty.factor[x1_cols] <- 0
  fit <- cv.glmnet(x = mm, y = V, family = "mgaussian", alpha = alpha, penalty.factor = penalty.factor);
  coefs_list <- coef(fit, s = lambda);
  print("coef(fit)[x1_cols]:")
  print(coef(fit)[x1_cols])
  print("head(mm[, x1_cols, drop=FALSE])")
  print(head(mm[, x1_cols, drop=FALSE]))
  print("head(mm[, x1_cols, drop=FALSE] %*% coef(fit)[x1_cols])")
  print(head(mm[, x1_cols, drop=FALSE] %*% coef(fit)[x1_cols]))
  # Extract x1 coefficients for each response variable
  x1_coefs <- lapply(coefs_list, function(coef_mat) {
    coef_mat[x1_cols, , drop = FALSE];
  });

  # Calculate x1 main effect contribution for each response variable
  x1_contribution <- matrix(NA, nrow = nrow(V), ncol = ncol(V));

  for (i in 1:ncol(V)) {
    if (length(x1_cols) > 0) {
      temp_result <- mm[, x1_cols, drop = FALSE] %*% x1_coefs[[i]];
      x1_contribution[, i] <- as.vector(temp_result);
    }
    else {
      # If no x1 coefficients, contribution is zero
      x1_contribution[, i] <- 0;
    }
  }
  colnames(x1_contribution) <- colnames(V);

  return(x1_contribution);
}
