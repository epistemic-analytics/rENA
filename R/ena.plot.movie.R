#####
#' @title Animated movie of growing ENA trajectories
#'
#' @description Creates an animated Plotly visualization of trajectories growing
#' across shared calendar time / conversation turns.
#'
#' @export
#'
#' @param enaplot \code{\link{ENAplot}} object to use for plotting base canvas
#' @param points Data frame or matrix of points with 2 coordinate dimensions
#' @param by Vector identifying trajectory groupings (e.g. speaker/unit)
#' @param time Monotonic time/turn index vector corresponding to points
#' @param names Character vector of labels for each trajectory
#' @param colors Character vector of colors for each trajectory
#' @param smooth Character indicating smoothing method: "none" (default, point-to-point) or "poly" (LOOCV-2D polynomial curve)
#' @param poly.degree Optional integer degree for polynomial fit. If NULL, selected automatically via LOOCV-2D
#' @param poly.max.degree Maximum polynomial degree to test in LOOCV-2D (default 3)
#' @param poly.eval.points Number of points along smooth curve (default 100)
#' @param show.points Logical; whether to show discrete point markers along the trajectory (default TRUE)
#' @param frame_ms Milliseconds per animation frame (default 250)
#' @param show_tips Logical; whether to show glowing tip markers at current time position
#' @param title Optional title string
#' @return Plotly widget with play/pause controls and slider
#' #####
ena.plot.movie = function(
  enaplot,
  points,
  by,
  time,
  names = NULL,
  colors = NULL,
  smooth = c("none", "poly"),
  poly.degree = NULL,
  poly.max.degree = 3L,
  poly.eval.points = 100L,
  show.points = TRUE,
  frame_ms = 250,
  show_tips = TRUE,
  title = NULL
) {
  if (!requireNamespace("plotly", quietly = TRUE)) {
    stop("plotly is required for animated trajectory movies")
  }

  if (is(points, "ena.matrix") || any(find_meta_cols(points))) {
    pts_clean <- remove_meta_data(points)
    pts_df <- data.frame(
      X1 = as.numeric(pts_clean[[1L]]),
      X2 = as.numeric(pts_clean[[2L]])
    )
  } else if (is.matrix(points)) {
    pts_df <- data.frame(
      X1 = as.numeric(points[, 1L]),
      X2 = as.numeric(points[, 2L])
    )
  } else {
    pts_raw <- as.data.frame(points)
    num_cols <- vapply(pts_raw, is.numeric, logical(1))
    if (sum(num_cols) >= 2L) {
      num_df <- pts_raw[, num_cols, drop = FALSE]
      pts_df <- data.frame(
        X1 = as.numeric(num_df[[1L]]),
        X2 = as.numeric(num_df[[2L]])
      )
    } else {
      stop("`points` must contain at least 2 numeric coordinate columns (X and Y).")
    }
  }
  dim_cols <- c("X1", "X2")

  by_vec <- as.character(by)
  time_vec <- as.numeric(time)

  unique_by <- unique(by_vec)
  n_by <- length(unique_by)

  if (is.null(names)) {
    names <- unique_by
  }
  if (is.null(colors)) {
    palette <- c("#1650FF", "#CD0BBC", "#00A86B", "#FF8C00", "#9932CC", "#008080")
    colors <- palette[((seq_len(n_by) - 1L) %% length(palette)) + 1L]
  }

  smooth <- match.arg(smooth)

  # Precompute polynomial curves if smooth == "poly"
  poly_curves <- list()
  if (smooth == "poly") {
    for (b_idx in seq_along(unique_by)) {
      u <- unique_by[b_idx]
      u_pts <- pts_df[by_vec == u, , drop = FALSE]
      if (nrow(u_pts) >= 2L) {
        curve_fit <- .fit_etm_poly_curve(
          points = u_pts[, dim_cols, drop = FALSE],
          degree = poly.degree,
          max_degree = poly.max.degree,
          criterion = "loocv"
        )
        poly_curves[[u]] <- as.matrix(.eval_etm_poly_curve(curve_fit, poly.eval.points))
      }
    }
  }

  # All unique time steps in chronological order
  all_times <- sort(unique(time_vec))
  if (length(all_times) == 0L) {
    stop("No valid time points provided for movie.")
  }

  # Build cumulative frame data
  frame_list <- vector("list", length(all_times) * n_by * 3L)
  fi <- 0L

  for (t_idx in seq_along(all_times)) {
    cur_t <- all_times[t_idx]
    for (b_idx in seq_along(unique_by)) {
      u <- unique_by[b_idx]
      u_all_mask <- (by_vec == u)
      u_mask <- u_all_mask & (time_vec <= cur_t)
      if (!any(u_mask)) next

      sub_pts <- pts_df[u_mask, , drop = FALSE]
      tip_pt <- sub_pts[nrow(sub_pts), , drop = FALSE]

      # Determine line coordinates: either smooth poly curve or discrete points
      if (smooth == "poly" && !is.null(poly_curves[[u]])) {
        total_n <- sum(u_all_mask)
        cur_n <- nrow(sub_pts)
        frac <- if (total_n > 1L) (cur_n - 1L) / (total_n - 1L) else 1.0
        n_eval <- max(2L, as.integer(ceiling(frac * nrow(poly_curves[[u]]))))
        curve_sub <- poly_curves[[u]][seq_len(min(n_eval, nrow(poly_curves[[u]]))), , drop = FALSE]
        line_x <- curve_sub[, 1L]
        line_y <- curve_sub[, 2L]
      } else {
        line_x <- sub_pts[[dim_cols[1L]]]
        line_y <- sub_pts[[dim_cols[2L]]]
      }

      fi <- fi + 1L
      frame_list[[fi]] <- data.frame(
        x = line_x,
        y = line_y,
        unit = u,
        unit_name = names[b_idx],
        color = colors[b_idx],
        time_frame = cur_t,
        trace_type = "line",
        stringsAsFactors = FALSE
      )

      if (isTRUE(show.points) && smooth == "poly") {
        fi <- fi + 1L
        frame_list[[fi]] <- data.frame(
          x = sub_pts[[dim_cols[1L]]],
          y = sub_pts[[dim_cols[2L]]],
          unit = u,
          unit_name = names[b_idx],
          color = colors[b_idx],
          time_frame = cur_t,
          trace_type = "points",
          stringsAsFactors = FALSE
        )
      }

      if (isTRUE(show_tips)) {
        fi <- fi + 1L
        frame_list[[fi]] <- data.frame(
          x = tip_pt[[dim_cols[1L]]],
          y = tip_pt[[dim_cols[2L]]],
          unit = u,
          unit_name = names[b_idx],
          color = colors[b_idx],
          time_frame = cur_t,
          trace_type = "tip",
          stringsAsFactors = FALSE
        )
      }
    }
  }

  movie_df <- do.call(rbind, frame_list[seq_len(fi)])

  # Add traces onto base enaplot
  p <- enaplot$plot

  for (b_idx in seq_along(unique_by)) {
    u <- unique_by[b_idx]
    u_line <- movie_df[movie_df$unit == u & movie_df$trace_type == "line", , drop = FALSE]

    p <- plotly::add_trace(
      p,
      data = u_line,
      x = ~x,
      y = ~y,
      frame = ~time_frame,
      name = names[b_idx],
      type = "scatter",
      mode = if (smooth == "poly") "lines" else (if (isTRUE(show.points)) "lines+markers" else "lines"),
      line = list(color = colors[b_idx], width = 2.5),
      marker = if (smooth != "poly" && isTRUE(show.points)) list(color = colors[b_idx], size = 5) else NULL,
      showlegend = TRUE
    )

    if (smooth == "poly" && isTRUE(show.points)) {
      u_pts <- movie_df[movie_df$unit == u & movie_df$trace_type == "points", , drop = FALSE]
      p <- plotly::add_trace(
        p,
        data = u_pts,
        x = ~x,
        y = ~y,
        frame = ~time_frame,
        name = paste0(names[b_idx], " (points)"),
        type = "scatter",
        mode = "markers",
        marker = list(color = colors[b_idx], size = 5, opacity = 0.7),
        showlegend = FALSE
      )
    }

    if (isTRUE(show_tips)) {
      u_tips <- movie_df[movie_df$unit == u & movie_df$trace_type == "tip", , drop = FALSE]
      p <- plotly::add_trace(
        p,
        data = u_tips,
        x = ~x,
        y = ~y,
        frame = ~time_frame,
        name = paste0(names[b_idx], " (head)"),
        type = "scatter",
        mode = "markers",
        marker = list(color = colors[b_idx], size = 12, symbol = "diamond"),
        showlegend = FALSE
      )
    }
  }

  p <- plotly::animation_opts(
    p,
    frame = frame_ms,
    transition = 0,
    redraw = TRUE
  )

  p <- plotly::animation_slider(
    p,
    currentvalue = list(prefix = "Time / Turn: ", font = list(color = "#333333"))
  )

  if (!is.null(title)) {
    p <- plotly::layout(p, title = list(text = title))
  }

  p
}
