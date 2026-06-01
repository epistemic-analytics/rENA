###
#' @title ENA Rotate by generalized means rotation (GMR)
#'
#' @description Computes a dimensional reduction from a matrix of ENA points
#'   such that the first dimension best represents the contribution of a target
#'   variable after controlling for covariates via Lasso. An optional second
#'   GMR axis can be computed for \code{y_var}; remaining dimensions are filled
#'   by SVD of the doubly-deflated space. Delegates to
#'   \code{\link[libqe]{generalized_means_rotation}}.
#'
#' @param enaset An \code{\link{ENAset}} or compatible list with
#'   \code{model$points.for.projection} (or \code{points.normed.centered}),
#'   \code{line.weights}, and \code{rotation$codes}.
#' @param params A list with the following named elements:
#'   \describe{
#'     \item{\code{x_var}}{Required. A \code{data.frame} (or character vector of
#'       column names in \code{enaset$meta.data}) whose first column is the
#'       target variable. Additional columns are treated as covariates and
#'       penalized via Lasso.}
#'     \item{\code{y_var}}{Optional. Same format as \code{x_var}. When provided
#'       a second GMR axis is computed.}
#'     \item{\code{select_2_groups}}{Optional length-2 list/vector of group
#'       labels. When given, the GMR fit for the x axis uses only rows whose
#'       target value is in these two groups. The group mean difference for x1
#'       (the secondary axis that keeps group means on the x-axis) is always
#'       computed from the full data.}
#'     \item{\code{interactions}}{Logical; if \code{TRUE} (default) pairwise
#'       interaction terms are added to the model matrix when covariates are
#'       present. Set \code{FALSE} for main-effects-only Lasso.}
#'   }
#'
#' @importFrom libqe generalized_means_rotation
#' @importFrom stats model.matrix as.formula
#' @export
#' @return A list with \code{rotation} (q x q matrix, column names GMR1,
#'   GMR2|SVD2, SVD3, …), \code{codes}, \code{eigenvalues}, and
#'   \code{node.positions = NULL}, suitable for use inside \code{rotate()}.
###
ena.rotate.by.generalized <- function(enaset, params) {

  ## ── Input validation ────────────────────────────────────────────────────────
  if (!is.list(params) || is.null(params$x_var)) {
    stop("params must be provided as a list() and provide `x_var`")
  }

  ## ── Resolve x_var → data.frame ──────────────────────────────────────────────
  if (!is.data.frame(params$x_var)) {
    if (all(params$x_var %in% colnames(enaset$meta.data))) {
      x <- enaset$meta.data[, params$x_var, with = FALSE]
    } else {
      stop(paste("x_var incorrect:", paste(params$x_var, collapse = ", ")))
    }
  } else {
    x <- params$x_var
  }

  ## ── ENA point matrix ────────────────────────────────────────────────────────
  V <- if (!is.null(enaset$points.normed.centered))
         as.matrix(enaset$points.normed.centered)
       else
         as.matrix(enaset$model$points.for.projection)

  ## ── Target variable & encoding ──────────────────────────────────────────────
  ## For categorical targets, encode as 0-based integer codes.
  ## When select_2_groups is provided, the two selected groups are encoded as
  ## 0 and 1 (required by the C++ x1 computation, which uses labels == 0/1).
  target_full   <- as.vector(x[[1]])
  x_categorical <- !is.numeric(target_full)

  if (x_categorical) {
    grp <- params$select_2_groups
    if (!is.null(grp) && length(grp) == 2) {
      all_levels <- c(grp[[1]], grp[[2]],
                      setdiff(unique(target_full), c(grp[[1]], grp[[2]])))
    } else {
      all_levels <- unique(target_full)
    }
    x_target_enc <- as.numeric(factor(target_full, levels = all_levels)) - 1.0
    x_n_groups   <- as.integer(length(all_levels))
  } else {
    x_target_enc <- as.numeric(target_full)
    x_n_groups   <- 0L
  }

  ## ── Row subset (select_2_groups → 0-based integer indices) ──────────────────
  if (!is.null(params$select_2_groups) && length(params$select_2_groups) == 2) {
    subset_rows <- which(target_full %in% params$select_2_groups)
    if (length(subset_rows) < 2L) {
      warning("select_2_groups produced < 2 matching rows; using all rows")
      x_subset <- integer(0)
    } else {
      x_subset <- as.integer(subset_rows - 1L)
    }
  } else {
    x_subset <- integer(0)
  }

  ## ── Model matrix for x ──────────────────────────────────────────────────────
  ## Interaction terms are included by default when covariates are present.
  interactions <- isTRUE(if (!is.null(params$interactions)) params$interactions else TRUE)
  fstr_x <- if (ncol(x) > 1L && interactions) "~ .^2" else "~ ."
  mm_x   <- model.matrix(as.formula(fstr_x), data = x)[, -1L, drop = FALSE]

  ## x1_cols (0-based): columns in mm_x that belong to the target variable
  ## (main-effect columns only; interaction columns stay penalized)
  x1_name  <- colnames(x)[1L]
  safe_x1  <- gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", x1_name)
  x1_regex <- paste0("^", safe_x1, "[^:]*$")
  x1_cols  <- as.integer(grep(x1_regex, colnames(mm_x)) - 1L)
  if (length(x1_cols) == 0L) x1_cols <- 0L  # guard: treat first col as target

  ## ── Y axis ──────────────────────────────────────────────────────────────────
  has_y <- !is.null(params$y_var)

  if (has_y) {
    if (!is.data.frame(params$y_var)) {
      if (all(params$y_var %in% colnames(enaset$meta.data))) {
        y <- enaset$meta.data[, params$y_var, with = FALSE]
      } else {
        stop("y_var must be a data.frame or a column name in enaset$meta.data")
      }
    } else {
      y <- params$y_var
    }
    y_target_raw  <- as.vector(y[[1]])
    y_categorical <- !is.numeric(y_target_raw)
    if (y_categorical) {
      y_levels     <- unique(y_target_raw)
      y_target_enc <- as.numeric(factor(y_target_raw, levels = y_levels)) - 1.0
      y_n_groups   <- as.integer(length(y_levels))
    } else {
      y_target_enc <- as.numeric(y_target_raw)
      y_n_groups   <- 0L
    }
    fstr_y  <- if (ncol(y) > 1L && interactions) "~ .^2" else "~ ."
    mm_y    <- model.matrix(as.formula(fstr_y), data = y)[, -1L, drop = FALSE]
    y1_name  <- colnames(y)[1L]
    safe_y1  <- gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", y1_name)
    y1_regex <- paste0("^", safe_y1, "[^:]*$")
    y1_cols  <- as.integer(grep(y1_regex, colnames(mm_y)) - 1L)
    if (length(y1_cols) == 0L) y1_cols <- 0L
  } else {
    ## Dummy y params — passed but ignored by the C++ when has_y = FALSE
    mm_y          <- matrix(0.0, nrow(V), 1L)
    y_target_enc  <- numeric(nrow(V))
    y1_cols       <- 0L
    y_categorical <- FALSE
    y_n_groups    <- 0L
  }

  ## ── Delegate to libqe ───────────────────────────────────────────────────────
  result <- libqe::generalized_means_rotation(
    V              = V,
    x_model_matrix = mm_x,
    x_target       = x_target_enc,
    x1_cols        = x1_cols,
    x_categorical  = x_categorical,
    x_n_groups     = x_n_groups,
    x_subset       = x_subset,
    has_y          = has_y,
    y_model_matrix = mm_y,
    y_target       = y_target_enc,
    y1_cols        = y1_cols,
    y_categorical  = y_categorical,
    y_n_groups     = y_n_groups
  )

  ## ── Assemble rotation matrix ─────────────────────────────────────────────────
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
