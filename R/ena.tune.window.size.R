#' Tune Window Size for ENA Accumulation
#'
#' Estimates the optimal moving window size for discourse accumulation and returns a new
#' accumulation object constructed with the tuned window size. By default, uses Cross-Covariance
#' Decay (CCD; \code{method = "ccd"}) to estimate the discourse coherence length.
#' Alternatively, the legacy SVD projection stability heuristic (\code{method = "stability"})
#' can be used.
#'
#' @param accum_object An \code{ENAAccumulation}/\code{ENAdata}/\code{ena.set} object.
#' @param min_size Integer. The minimum window size (default=1) to test.
#' @param max_size Integer. The maximum window size (default=20) to test.
#' @param method Character. Window estimation method: \code{"ccd"} (default, Cross-Covariance Decay)
#'   or \code{"stability"} (legacy SVD stability plateau).
#' @param cutoff Numeric. The threshold (default 0.95) of the maximum correlation used when
#'   \code{method = "stability"}.
#' @param min_overlap Integer. Minimum required overlapping rows per conversation when
#'   \code{method = "ccd"} (default=10).
#' @param ... Additional arguments passed to the underlying window estimation function.
#'
#' @details
#' When \code{method = "ccd"} (default), the function uses \code{\link{ena.ccd.window}} to calculate
#' the discourse coherence half-life decay lag directly from the conversation stream.
#'
#' When \code{method = "stability"}, the function iteratively rebuilds accumulation objects across
#' candidate window sizes, generates ENA sets, and computes distance-space correlations
#' between adjacent window sizes until reaching \code{cutoff * max_correlation}.
#'
#' @return A new \code{ENAdata}/\code{ena.set} object accumulated with the \code{best_window_size}.
#'
#' @export
#' @importFrom rENA ena.make.set ena_space_dist_corr ena.ccd.window
#'
#' @examples
#' \dontrun{
#' data(RS.data)
#' codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
#'                "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
#' accum <- ena.accumulate.data(
#'   units = RS.data[, c("UserName", "Condition")],
#'   conversation = RS.data[, c("Condition", "GroupName")],
#'   codes = RS.data[, codeNames],
#'   window.size.back = 4
#' )
#' tuned_accum <- ena.tune.window.size(accum, method = "ccd")
#' }
ena.tune.window.size <- function(
  accum_object,
  min_size = 1,
  max_size = 20,
  method = c("ccd", "stability"),
  cutoff = 0.95,
  min_overlap = 10,
  ...
) {
  method <- match.arg(method)

  if (method == "ccd") {
    best_window_size <- ena.ccd.window(
      x = accum_object,
      max_window = max_size,
      min_overlap = min_overlap
    )
  } else {
    # Legacy stability plateau method
    orig_call <- accum_object$`_function.call`
    call_list <- as.list(orig_call)

    window_range <- min_size:max_size
    all_points <- list()

    for (i in seq_along(window_range)) {
      window_size <- window_range[i]
      call_list[["window.size.back"]] <- window_size
      new_call <- as.call(call_list)
      new_accum <- eval(new_call, envir = parent.frame())
      curr_set <- rENA::ena.make.set(new_accum)
      points <- as.matrix(curr_set$points)
      all_points[[i]] <- points
    }

    n_steps <- length(window_range) - 1
    adj_correlations <- numeric(n_steps)

    for (i in 1:n_steps) {
      adj_correlations[i] <- rENA::ena_space_dist_corr(all_points[[i]], all_points[[i + 1]])
    }

    max_corr <- max(adj_correlations, na.rm = TRUE)
    threshold <- cutoff * max_corr
    best_idx <- which(adj_correlations >= threshold)[1]
    best_window_size <- window_range[best_idx]
  }

  # Rebuild accumulation at best_window_size
  # Method 1: Try evaluating modified orig_call if available and valid
  orig_call <- accum_object$`_function.call`
  if (!is.null(orig_call)) {
    call_list <- as.list(orig_call)
    call_name <- paste(deparse(call_list[[1]]), collapse = " ")
    if (grepl("ena.accumulate.data", call_name) || grepl("accumulate", call_name)) {
      call_list[["window.size.back"]] <- best_window_size
      final_call <- as.call(call_list)
      res <- tryCatch(eval(final_call, envir = parent.frame()), error = function(e) NULL)
      if (!is.null(res)) return(res)
    }
  }

  # Method 2: Robust fallback - rebuild directly from object fields
  raw_df <- if (!is.null(accum_object$model$raw.input)) {
    as.data.frame(accum_object$model$raw.input)
  } else if (!is.null(accum_object$raw)) {
    as.data.frame(accum_object$raw)
  } else if (!is.null(accum_object$data)) {
    as.data.frame(accum_object$data)
  } else if (!is.null(accum_object$`_function.params`$data)) {
    as.data.frame(accum_object$`_function.params`$data)
  } else {
    NULL
  }

  if (!is.null(raw_df) && any(duplicated(colnames(raw_df)))) {
    raw_df <- raw_df[, !duplicated(colnames(raw_df)), drop = FALSE]
  }

  units_by <- if (!is.null(accum_object$units.by)) {
    accum_object$units.by
  } else if (!is.null(accum_object$model$units.by)) {
    accum_object$model$units.by
  } else if (!is.null(accum_object$`_function.params`$units.by)) {
    accum_object$`_function.params`$units.by
  } else if (!is.null(accum_object$unit.names)) {
    accum_object$unit.names
  } else {
    NULL
  }

  convo_by <- if (!is.null(accum_object$conversations.by)) {
    accum_object$conversations.by
  } else if (!is.null(accum_object$model$conversations.by)) {
    accum_object$model$conversations.by
  } else if (!is.null(accum_object$`_function.params`$conversations.by)) {
    accum_object$`_function.params`$conversations.by
  } else {
    NULL
  }

  codes_by <- if (!is.null(accum_object$model$codes)) {
    accum_object$model$codes
  } else if (!is.null(accum_object$codes)) {
    if (is.data.frame(accum_object$codes) || is.matrix(accum_object$codes)) {
      colnames(accum_object$codes)
    } else {
      as.character(accum_object$codes)
    }
  } else if (!is.null(accum_object$`_function.params`$codes)) {
    if (is.data.frame(accum_object$`_function.params`$codes) || is.matrix(accum_object$`_function.params`$codes)) {
      colnames(accum_object$`_function.params`$codes)
    } else {
      as.character(accum_object$`_function.params`$codes)
    }
  } else {
    NULL
  }

  if (!is.null(raw_df) && !is.null(units_by) && !is.null(convo_by) && !is.null(codes_by)) {
    return(ena.accumulate.data(
      units = raw_df[, units_by, drop = FALSE],
      conversation = raw_df[, convo_by, drop = FALSE],
      codes = raw_df[, codes_by, drop = FALSE],
      window.size.back = best_window_size
    ))
  }

  return(best_window_size)
}
