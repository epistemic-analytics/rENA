#' Correlation between distances in two ENA spaces
#'
#' @description
#' Calculates the Pearson correlation between the pairwise Euclidean distances
#' of points in two ENA spaces (\code{A} and \code{B}). For smaller datasets,
#' it computes the exact correlation. For larger datasets, it estimates the
#' correlation using a sampled subset of pairs.
#'
#' @param A A matrix or data frame representing the first ENA space (rows as points).
#' @param B A matrix or data frame representing the second ENA space (must have the same number of rows as A).
#' @param max_sample_size Numeric. The maximum number of pairwise distances to compute.
#' If the total possible pairs exceeds this value, sampling is used. Default is 100,000.
#'
#' @return A numeric value representing the Pearson correlation.
#' @importFrom stats dist cor
#' @export
ena_space_dist_corr <- function(A, B, max_sample_size = 100000) {
  m <- nrow(A)

  if (is.null(m) || m == 0 || nrow(B) != m) {
    stop("The spaces must have the same non-zero number of rows.")
  }

  # Calculate total unique pairs m(m-1)/2
  total_possible_pairs <- choose(m, 2)

  # Use Exact if total pairs is less than limit
  if (total_possible_pairs <= max_sample_size) {
    # CASE 1: Small m - Exact calculation
    d_A <- as.vector(dist(A))
    d_B <- as.vector(dist(B))
    return(cor(d_A, d_B, method = "pearson"))

  } else {
    # CASE 2: Large m - Simple Sample & Filter
    # Sample indices with replacement
    idx1 <- sample.int(m, max_sample_size, replace = TRUE)
    idx2 <- sample.int(m, max_sample_size, replace = TRUE)

    # Filter out identity pairs (per user instruction for large m)
    keep <- idx1 != idx2
    idx1 <- idx1[keep]
    idx2 <- idx2[keep]

    # Vectorized Euclidean Distance: sqrt(sum((x-y)^2))
    dist_A <- sqrt(rowSums((A[idx1, , drop = FALSE] - A[idx2, , drop = FALSE])^2))
    dist_B <- sqrt(rowSums((B[idx1, , drop = FALSE] - B[idx2, , drop = FALSE])^2))

    return(cor(dist_A, dist_B, method = "pearson"))
  }
}
