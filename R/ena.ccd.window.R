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
  # Factors and characters are converted by their labels ("0"/"1" -> 0/1);
  # data.matrix() would use factor level positions (1/2) instead. Missing or
  # non-numeric values are an error rather than a silent 0.
  code_mat <- vapply(raw_df[, codeNames, drop = FALSE], function(col) {
    if (is.factor(col)) col <- as.character(col)
    suppressWarnings(as.numeric(col))
  }, numeric(nrow(raw_df)))
  code_mat <- matrix(code_mat, nrow = nrow(raw_df), dimnames = list(NULL, codeNames))
  bad <- codeNames[colSums(is.na(code_mat)) > 0]
  if (length(bad)) {
    stop("Code columns have missing or non-numeric values: ", paste(bad, collapse = ", "))
  }

  conv_factor <- interaction(raw_df[conversation_cols], drop = TRUE, lex.order = FALSE)
  x_subsets   <- split.data.frame(code_mat, conv_factor)

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

  # 4. Delegate the cross-covariance decay computation to the shared libqe
  #    kernel (qe::ccd_window). The numeric core lives in C++ so that R, the
  #    WASM build, and the Python package (ena) all share a single implementation; only the
  #    data.frame wrangling and S3 assembly stay here.
  kern <- libqe::ccd_window(
    lapply(x_subsets, function(s) matrix(as.numeric(s), nrow = nrow(s))),
    max_window  = max_window,
    min_overlap = min_overlap
  )

  pooled_out <- data.frame(
    lag                  = kern$lag,
    frob                 = kern$frob,
    frob_sq_unbiased     = kern$frob_sq_unbiased,
    frob_unbiased_signed = kern$frob_unbiased_signed,
    total_weight         = kern$total_weight,
    stringsAsFactors     = FALSE
  )

  best_window <- as.integer(kern$window_size)
  peak_lag    <- as.integer(kern$peak_lag)

  # 5. Preserve the informational warnings the pure-R implementation emitted.
  #    (The window size / peak lag themselves are decided inside the kernel.)
  f <- pooled_out$frob_unbiased_signed
  if (peak_lag == 0L) {
    warning("Corrected Cross Covariance is non-positive or all NA across evaluated lags. Defaulting to window size = 1.")
  } else {
    max_f <- f[pooled_out$lag == peak_lag]
    after <- pooled_out$lag >= peak_lag
    if (!any((f[after] / max_f) <= 0.5, na.rm = TRUE)) {
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
