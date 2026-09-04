.fit_etm_poly_curve <- function(
  points,
  degree = NULL,
  max_degree = 3L,
  criterion = c("loocv", "aic")
) {
  criterion <- match.arg(criterion)
  pts <- as.data.frame(points)

  if (ncol(pts) < 2L) {
    stop("ETM polynomial trajectory fitting requires at least two coordinate columns.")
  }

  tma::tma_fit_poly_curve(
    pts = data.frame(
      x = as.numeric(pts[[1L]]),
      y = as.numeric(pts[[2L]])
    ),
    x_col = "x",
    y_col = "y",
    degree = degree,
    max_degree = as.integer(max_degree),
    criterion = criterion,
    fit_curve_with_zero_pts = TRUE
  )
}

.eval_etm_poly_curve <- function(curve, n_eval) {
  t_eval <- seq(0, 1, length.out = as.integer(n_eval))
  data.frame(
    x = curve$pred_x(t_eval),
    y = curve$pred_y(t_eval)
  )
}
