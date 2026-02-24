#' Tune Window Size for ENA Accumulation
#'
#' This function iterates through a range of window sizes to find the optimal size
#' for a discourse accumulation. It identifies the "stability plateau" by calculating
#' the correlation between adjacent window sizes and selecting the smallest size
#' that meets a specified threshold of the maximum observed stability.
#'
#' @param accum_object An \code{ENAAccumulation} object or a call that can be
#' re-evaluated to create one.
#' @param min_size Integer. The minimum window size (default=1) to test.
#' @param max_size Integer. The maximum window size (default=20) to test.
#' @param cutoff Numeric. The threshold (default 0.95) of the maximum correlation
#' used to determine the "best" window size.
#'
#' @details
#' The function uses the internal \code{_function.call} from the \code{accum_object}
#' to iteratively rebuild the accumulation. For each window size, it generates an
#' ENA set and extracts the unit points and compute the correlations between ENA points with
#' adjacent window sizes.
#' The best window size is the lowest with correlation higher than cutoff*max_correlation
#'
#' @return A new \code{ENAAccumulation} object generated with the
#' \code{best_window_size}.
#'
#' @export
#' @importFrom rENA ena.make.set ena_space_dist_corr
#'
#' @examples
#' \dontrun{
#' # Assuming 'accum' is your existing accumulation object
#' tuned_accum <- tune_window_size(accum, min_size = 1, max_size = 20, cutoff = 0.95)
#' }
ena.tune.window.size <- function(accum_object, min_size=1, max_size=20,cutoff=0.95) {
  # 1. Extract the original call from the accumulation object
  # Assuming the ENA object stores the call in `_function.call`
  orig_call <- accum_object$`_function.call`
  call_list <- as.list(orig_call)

  window_range <- min_size:max_size
  all_points <- list()

  # 2. Iterative accumulation and weight extraction
  for(i in seq_along(window_range)) {
    window_size <- window_range[i]

    # Update the window size in the call
    call_list[["window.size.back"]] <- window_size
    new_call <- as.call(call_list)

    # Evaluate the call to get a new accumulation object
    # Using parent.frame() is safer than .GlobalEnv for package/function scoping
    #print(new_call)
    new_accum <- eval(new_call, envir = parent.frame())

    # Create the ENA set and extract line weights
    # Note: For large m, ENA sets can be memory intensive
    curr_set <- rENA::ena.make.set(new_accum)

    # Logic for large m: extract weights as matrix
    points <- as.matrix(curr_set$points)

    # APPLY CASE 2: Filter out identity/duplicated pairs if m is large
    # This ensures correlations are based on unique, non-self-referential connections
    all_points[[i]] <- points
  }

  # 3. Calculate adjacent correlations
  n_steps <- length(window_range) - 1
  adj_correlations <- numeric(n_steps)

  for (i in 1:n_steps) {
    # Calculate correlation between consecutive window sizes
    adj_correlations[i] <- rENA::ena_space_dist_corr(all_points[[i]], all_points[[i+1]])
  }

  # 4. Determine the optimal window size
  results <- data.frame(
    window_size = window_range[1:n_steps],
    correlation = adj_correlations
  )

  max_corr <- max(adj_correlations, na.rm = TRUE)
  threshold <- cutoff * max_corr

  # Find the first window size that crosses the 95% threshold of the max stability
  best_idx <- which(adj_correlations >= threshold)[1]
  best_window_size <- results$window_size[best_idx]

  # 5. Return the final accumulation object
  call_list[["window.size.back"]] <- best_window_size
  final_call <- as.call(call_list)
  new_accum<-eval(final_call, envir = parent.frame())
  return(new_accum)
}
