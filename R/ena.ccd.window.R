#' Calculate ENA Moving Window Size via Cross-Covariance Decay (CCD)
#'
#' Calculates the recommended moving window size for Epistemic Network Analysis (ENA)
#' by estimating the half-life decay lag of the noise-corrected Frobenius norm across
#' pooled conversation cross-covariance matrices.
#'
#' @param x A \code{data.frame}, \code{data.table}, or an \code{ENAdata}/\code{ena.set} accumulation object.
#' @param codeNames A \code{character} vector of column names representing binary codes (optional if \code{x} is an ENA object).
#' @param conversation_cols A \code{character} vector of column names defining discrete conversations (optional if \code{x} is an ENA object).
#' @param max_window A \code{numeric} value indicating the maximum lag window size to evaluate. Default is \code{20}.
#' @param min_overlap A \code{numeric} value specifying the minimum required overlapping rows (\eqn{N - lag}) per conversation subset. Default is \code{10}.
#'
#' @details
#' The function computes pooled cross-covariance curves over lags \code{0:max_window}. It normalizes
#' the noise-corrected Frobenius norm relative to its peak value and identifies the first lag step strictly
#' after the peak where the normalized norm falls below 0.5 (half-life threshold).
#'
#' @references
#' Shaffer, D. W. & Cai, Z. (2026). Discourse Coherence Length:
#' Noise-Corrected Covariance Estimation of Window-Size in Epistemic Network Analysis.
#' International Conference on Quantitative Ethnography (ICQE26).
#'
#' @return An integer scalar representing the estimated half-life lag window size.
#'
#' @export
#'
#' @examples
#' data(RS.data)
#' codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
#'                "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
#' w <- ena.ccd.window(RS.data, codeNames = codeNames,
#'                     conversation_cols = c("Condition", "GroupName"))
#' print(w)
ena.ccd.window <- function(
  x,
  codeNames = NULL,
  conversation_cols = NULL,
  max_window = 20,
  min_overlap = 10
) {
  res <- ena.ccd(
    x = x,
    codeNames = codeNames,
    conversation_cols = conversation_cols,
    max_window = max_window,
    min_overlap = min_overlap
  )
  return(res$window_size)
}

#' Compute Cross-Covariance Decay Curves and Noise Floor
#'
#' Evaluates window-matched cross-covariance matrices and noise-floor corrected
#' Frobenius norms across multiple conversation subsets over a range of lag steps.
#'
#' @param x A \code{data.frame}, \code{data.table}, or an \code{ENAdata}/\code{ena.set} accumulation object.
#' @param codeNames A \code{character} vector of column names corresponding to ENA codes.
#' @param conversation_cols A \code{character} vector of column names defining discrete conversations.
#' @param max_window An \code{integer} specifying the maximum lag to evaluate. Default is \code{20}.
#' @param min_overlap An \code{integer} specifying the minimum effective row overlap required per conversation at lag \eqn{l}. Default is \code{10}.
#'
#' @return An S3 object of class \code{ena.ccd} containing:
#' \describe{
#'   \item{window_size}{The estimated optimal window size (integer).}
#'   \item{peak_lag}{The lag corresponding to the peak cross-covariance norm.}
#'   \item{curves}{A \code{data.frame} of pooled cross-covariance metrics by lag.}
#'   \item{codeNames}{The evaluated code names.}
#'   \item{conversation_cols}{The conversation column names.}
#' }
#'
#' @export
#'
#' @examples
#' data(RS.data)
#' codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
#'                "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
#' ccd_res <- ena.ccd(RS.data, codeNames = codeNames,
#'                    conversation_cols = c("Condition", "GroupName"))
#' print(ccd_res)
#' plot(ccd_res)
ena.ccd <- function(
  x,
  codeNames = NULL,
  conversation_cols = NULL,
  max_window = 20,
  min_overlap = 10
) {
  # 1. Extract from ENAdata / ena.set if provided
  if (inherits(x, c("ENAdata", "ena.set", "ENAset", "rENA.data", "rENA.set"))) {
    if (is.null(codeNames)) {
      if (!is.null(x$model$codes)) {
        codeNames <- x$model$codes
      } else if (!is.null(x$codes)) {
        codeNames <- if (is.data.frame(x$codes) || is.matrix(x$codes)) colnames(x$codes) else as.character(x$codes)
      } else if (!is.null(x$`_function.params`$codes)) {
        codeNames <- if (is.data.frame(x$`_function.params`$codes) || is.matrix(x$`_function.params`$codes)) {
          colnames(x$`_function.params`$codes)
        } else {
          as.character(x$`_function.params`$codes)
        }
      }
    }
    if (is.null(conversation_cols)) {
      if (!is.null(x$conversations.by)) {
        conversation_cols <- x$conversations.by
      } else if (!is.null(x$model$conversations.by)) {
        conversation_cols <- x$model$conversations.by
      } else if (!is.null(x$`_function.params`$conversations.by)) {
        conversation_cols <- x$`_function.params`$conversations.by
      }
    }
    raw_df <- if (!is.null(x$model$raw.input)) {
      as.data.frame(x$model$raw.input)
    } else if (!is.null(x$raw)) {
      as.data.frame(x$raw)
    } else if (!is.null(x$data)) {
      as.data.frame(x$data)
    } else if (!is.null(x$`_function.params`$data)) {
      as.data.frame(x$`_function.params`$data)
    } else {
      NULL
    }
  } else if (is.data.frame(x)) {
    raw_df <- as.data.frame(x)
  } else {
    stop("'x' must be a data.frame or an ENA accumulation/set object.")
  }

  if (is.null(raw_df)) {
    stop("Could not extract raw data from the provided ENA object.")
  }

  # Deduplicate columns in raw_df if present (e.g. from intersecting units/convo specifications)
  if (any(duplicated(colnames(raw_df)))) {
    raw_df <- raw_df[, !duplicated(colnames(raw_df)), drop = FALSE]
  }

  if (is.null(codeNames) || length(codeNames) == 0) {
    stop("'codeNames' must be specified.")
  }
  if (is.null(conversation_cols) || length(conversation_cols) == 0) {
    stop("'conversation_cols' must be specified.")
  }

  # 2. Validate columns existence
  missing_cols <- setdiff(c(conversation_cols, codeNames), colnames(raw_df))
  if (length(missing_cols) > 0) {
    stop("The following columns were not found in 'x': ", paste(missing_cols, collapse = ", "))
  }

  # 3. Numeric matrix conversion & conversation splitting
  code_mat <- data.matrix(raw_df[, codeNames, drop = FALSE])
  if (any(is.na(code_mat))) {
    code_mat[is.na(code_mat)] <- 0
  }

  conv_factor <- interaction(raw_df[conversation_cols], drop = TRUE, lex.order = FALSE)
  x_subsets   <- split.data.frame(code_mat, conv_factor)

  C <- length(codeNames)
  lags <- 0:max_window

  # Pre-filter conversation subsets by length
  sub_lens <- vapply(x_subsets, nrow, integer(1))
  valid_idx <- which(sub_lens >= min_overlap)

  if (length(valid_idx) == 0) {
    warning(paste0("No conversation subsets had length >= min_overlap (", min_overlap, "). Returning window size = 1."))
    out_curves <- data.frame(
      lag                  = lags,
      frob                 = NA_real_,
      frob_sq_unbiased     = NA_real_,
      frob_unbiased_signed = NA_real_,
      total_weight         = 0,
      stringsAsFactors     = FALSE
    )
    res <- list(
      window_size       = 1L,
      peak_lag          = 0L,
      curves            = out_curves,
      codeNames         = codeNames,
      conversation_cols = conversation_cols
    )
    class(res) <- "ena.ccd"
    return(res)
  }

  x_subsets <- x_subsets[valid_idx]
  sub_lens  <- sub_lens[valid_idx]
  m <- length(x_subsets)

  # 4. Compute cross-covariance curves & noise floor across lags
  pooled_out <- data.frame(
    lag                  = lags,
    frob                 = NA_real_,
    frob_sq_unbiased     = NA_real_,
    frob_unbiased_signed = NA_real_,
    total_weight         = 0,
    stringsAsFactors     = FALSE
  )

  for (i in seq_along(lags)) {
    l <- lags[i]
    Cov_sum <- matrix(0, nrow = C, ncol = C)
    total_weight <- 0
    noise_floor_sq_weighted_sum <- 0

    for (k in 1:m) {
      N_k <- sub_lens[k]
      weight <- N_k - l
      if (weight < min_overlap) next

      X_k <- x_subsets[[k]]
      A <- X_k[(l + 1):N_k, , drop = FALSE]
      B <- X_k[1:(N_k - l), , drop = FALSE]

      p_A <- colMeans(A)
      p_B <- colMeans(B)

      Cov_k <- (crossprod(B, A) / weight) - outer(p_B, p_A)

      # Vectorized fast trace variance without memory copying
      tr_var_A <- sum(colSums((A - rep(p_A, each = weight))^2)) / (weight - 1)
      tr_var_B <- sum(colSums((B - rep(p_B, each = weight))^2)) / (weight - 1)
      var_k_sq <- tr_var_A * tr_var_B

      Cov_sum <- Cov_sum + weight * Cov_k
      total_weight <- total_weight + weight
      noise_floor_sq_weighted_sum <- noise_floor_sq_weighted_sum + (weight * var_k_sq)
    }

    if (total_weight > 0) {
      Cov_pooled <- Cov_sum / total_weight
      frob_sq_pooled <- sum(Cov_pooled^2)
      noise_floor_sq_pooled <- noise_floor_sq_weighted_sum / (total_weight^2)
      frob_sq_unbiased_pooled <- frob_sq_pooled - noise_floor_sq_pooled

      pooled_out$frob[i]                 <- sqrt(frob_sq_pooled)
      pooled_out$frob_sq_unbiased[i]     <- frob_sq_unbiased_pooled
      pooled_out$frob_unbiased_signed[i] <- sign(frob_sq_unbiased_pooled) * sqrt(abs(frob_sq_unbiased_pooled))
      pooled_out$total_weight[i]         <- total_weight
    }
  }

  # 5. Half-life decay lag detection
  f <- pooled_out$frob_unbiased_signed
  post_zero_mask <- lags > 0 & !is.na(f) & f > 0

  if (!any(post_zero_mask)) {
    warning("Corrected Cross Covariance is non-positive or all NA across evaluated lags. Defaulting to window size = 1.")
    best_window <- 1L
    peak_lag <- 0L
  } else {
    peak_sub_idx <- which.max(f[post_zero_mask])
    peak_lag     <- lags[post_zero_mask][peak_sub_idx]
    max_f        <- f[post_zero_mask][peak_sub_idx]

    after_peak_mask <- lags >= peak_lag
    f_after_peak    <- f[after_peak_mask]
    lags_after_peak <- lags[after_peak_mask]

    decay_idx <- which(f_after_peak / max_f <= 0.5)

    if (length(decay_idx) > 0) {
      best_window <- as.integer(lags_after_peak[decay_idx[1]])
    } else {
      valid_lags <- lags_after_peak[!is.na(f_after_peak)]
      best_window <- if (length(valid_lags) > 0) as.integer(tail(valid_lags, 1)) else 1L
      warning(paste0("Cross-covariance did not decay below half-life (50%) within max_window = ", max_window, "."))
    }
  }

  res <- list(
    window_size       = best_window,
    peak_lag          = peak_lag,
    curves            = pooled_out,
    codeNames         = codeNames,
    conversation_cols = conversation_cols
  )
  class(res) <- "ena.ccd"
  return(res)
}

#' @export
print.ena.ccd <- function(x, ...) {
  cat("ENA Cross-Covariance Decay (CCD) Window Size Estimation\n")
  cat("------------------------------------------------------\n")
  cat("Estimated Window Size :", x$window_size, "\n")
  cat("Peak Lag              :", x$peak_lag, "\n")
  cat("Codes Evaluated       :", paste(x$codeNames, collapse = ", "), "\n")
  cat("Conversations By      :", paste(x$conversation_cols, collapse = ", "), "\n")
  invisible(x)
}

#' Plot Cross-Covariance Decay Curve
#'
#' Plots the noise-corrected Frobenius norm across lags with the half-life threshold marker.
#'
#' @param x An object of class \code{ena.ccd}.
#' @param ... Additional arguments passed to \code{plot}.
#'
#' @return The \code{ena.ccd} object invisibly.
#' @export
plot.ena.ccd <- function(x, ...) {
  df <- x$curves
  valid <- !is.na(df$frob_unbiased_signed)
  df_sub <- df[valid, ]

  if (nrow(df_sub) == 0) {
    message("No valid cross-covariance curve points to plot.")
    return(invisible(x))
  }

  ylim <- range(c(0, df_sub$frob_unbiased_signed, df_sub$frob), na.rm = TRUE)
  graphics::plot(
    df_sub$lag, df_sub$frob_unbiased_signed,
    type = "b", pch = 19, col = "royalblue",
    xlab = "Lag (Window Size)",
    ylab = "Frobenius Norm",
    main = paste0("Cross-Covariance Decay (Estimated Window = ", x$window_size, ")"),
    ylim = ylim,
    ...
  )
  graphics::lines(df_sub$lag, df_sub$frob, type = "l", lty = 2, col = "gray50")
  graphics::abline(v = x$window_size, col = "firebrick", lty = 2, lwd = 2)
  graphics::legend(
    "topright",
    legend = c("Corrected Norm", "Uncorrected Norm", paste0("Chosen Window (", x$window_size, ")")),
    col = c("royalblue", "gray50", "firebrick"),
    lty = c(1, 2, 2), pch = c(19, NA, NA), lwd = c(1, 1, 2),
    bty = "n"
  )
  invisible(x)
}
