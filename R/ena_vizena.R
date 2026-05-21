## ── VizENA htmlwidgets integration ───────────────────────────────────────────
##
## Public API
##   ena_plot_vizena()   — create a VizENA htmlwidget from an ena.set
##   vizenaOutput()      — Shiny output binding
##   renderVizena()      — Shiny render function
##
## Internal helpers
##   .ena_to_vizena_data()     — convert ena.set to ENAModelData list
##   .ena_frame()              — build an ENADataFrame list from a data.frame
##   .vizena_group_ci()        — 95% t-interval boxes per group
##   .vizena_group_outlier()   — IQR-based outlier boxes per group
## ─────────────────────────────────────────────────────────────────────────────


# ── Internal helpers ──────────────────────────────────────────────────────────

#' Build an ENADataFrame list from a plain data.frame.
#' @noRd
.ena_frame <- function(df) {
  list(
    data  = lapply(seq_len(nrow(df)), function(i) as.list(df[i, , drop = FALSE])),
    types = as.list(setNames(
      sapply(df, function(col) {
        if (is.numeric(col))   "numeric"
        else if (is.integer(col)) "integer"
        else                   "character"
      }),
      names(df)
    ))
  )
}

#' Compute per-group 95% CI bounding boxes (t-interval on group mean).
#' Returns a data.frame with columns: group, {dim}.low, {dim}.high for each dim.
#' @noRd
.vizena_group_ci <- function(points_df, group_col, dim_cols, conf_level = 0.95) {
  groups <- unique(points_df[[group_col]])
  rows <- lapply(groups, function(g) {
    sub   <- points_df[points_df[[group_col]] == g, dim_cols, drop = FALSE]
    n     <- nrow(sub)
    if (n < 2L) return(NULL)
    means <- colMeans(sub, na.rm = TRUE)
    sds   <- apply(sub, 2, sd, na.rm = TRUE)
    t_val <- qt((1 + conf_level) / 2, df = n - 1L)
    row   <- as.list(
      c(
        group = g,
        setNames(
          as.numeric(rbind(means - t_val * sds / sqrt(n),
                           means + t_val * sds / sqrt(n))),
          as.vector(rbind(paste0(dim_cols, ".low"), paste0(dim_cols, ".high")))
        )
      )
    )
    as.data.frame(row, stringsAsFactors = FALSE)
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0L) return(NULL)
  do.call(rbind, rows)
}

#' Compute per-group IQR-based outlier bounding boxes.
#' Returns a data.frame with columns: group, {dim}.low, {dim}.high for each dim.
#' @noRd
.vizena_group_outlier <- function(points_df, group_col, dim_cols, iqr_factor = 1.5) {
  groups <- unique(points_df[[group_col]])
  rows <- lapply(groups, function(g) {
    sub <- points_df[points_df[[group_col]] == g, dim_cols, drop = FALSE]
    if (nrow(sub) < 1L) return(NULL)
    row <- list(group = g)
    for (d in dim_cols) {
      q1 <- quantile(sub[[d]], 0.25, na.rm = TRUE)
      q3 <- quantile(sub[[d]], 0.75, na.rm = TRUE)
      iqr <- q3 - q1
      row[[paste0(d, ".low")]]  <- as.numeric(q1 - iqr_factor * iqr)
      row[[paste0(d, ".high")]] <- as.numeric(q3 + iqr_factor * iqr)
    }
    as.data.frame(row, stringsAsFactors = FALSE)
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0L) return(NULL)
  do.call(rbind, rows)
}

#' Convert an ena.set to the ModelData list expected by qeviz.
#'
#' @param set        An \code{ena.set} object.
#' @param group_col  Character. Name of the grouping column present in
#'                   \code{set$points}. If \code{NULL} no group colouring is applied.
#' @param dim_cols   Character vector of dimension column names to include.
#'                   Defaults to \code{c("SVD1","SVD2")}.
#' @param include_ci Logical. Include 95\% CI bounds in the groups frame. Default TRUE.
#' @param conf_level Numeric. Confidence level for CI boxes. Default 0.95.
#' @param iqr_factor Numeric. IQR multiplier for outlier boxes (deprecated). Default 1.5.
#' @return A named list conforming to qeviz ModelData.
#' @noRd
.ena_to_vizena_data <- function(set,
                                 group_col  = NULL,
                                 dim_cols   = c("SVD1", "SVD2"),
                                 include_ci = TRUE,
                                 conf_level = 0.95,
                                 iqr_factor = 1.5) {

  # ── nodes ──────────────────────────────────────────────────────────────────
  node_pos <- as.data.frame(set$rotation$nodes)[, c("code", dim_cols), drop = FALSE]
  nodes    <- .ena_frame(node_pos)

  # ── edges ──────────────────────────────────────────────────────────────────
  # connection.counts has metadata columns (ena.metadata class) followed by
  # edge-weight columns (ena.co.occurrence class).  Edge column names use the
  # rENA " & " separator; qeviz expects "." — rename them here.
  cc       <- as.data.frame(set$connection.counts)
  is_edge  <- sapply(cc, function(x) inherits(x, "ena.co.occurrence"))
  edge_cc  <- cc[, is_edge, drop = FALSE]
  names(edge_cc) <- gsub(" & ", ".", names(edge_cc), fixed = TRUE)
  edge_cc$QEUNIT <- as.character(cc$ENA_UNIT)
  # Ensure QEUNIT is first column
  edge_cc  <- edge_cc[, c("QEUNIT", setdiff(names(edge_cc), "QEUNIT")), drop = FALSE]
  edges    <- .ena_frame(edge_cc)

  # ── points ─────────────────────────────────────────────────────────────────
  pts <- as.data.frame(set$points)
  # Keep only QEUNIT, the group column (if any), and the requested dimensions.
  # Exclude all other metadata columns to prevent mis-detection of group.
  keep_cols <- c("ENA_UNIT", group_col, dim_cols)
  pts       <- pts[, keep_cols[keep_cols %in% names(pts)], drop = FALSE]
  names(pts)[names(pts) == "ENA_UNIT"] <- "QEUNIT"
  # Coerce group column to plain character (strips ena.metadata class)
  if (!is.null(group_col) && group_col %in% names(pts)) {
    pts[[group_col]] <- as.character(pts[[group_col]])
  }
  for (d in dim_cols) {
    if (d %in% names(pts)) pts[[d]] <- as.numeric(pts[[d]])
  }
  points <- .ena_frame(pts)

  result <- list(
    nodes   = nodes,
    edges   = edges,
    points  = points,
    updated = as.numeric(Sys.time()) * 1000,  # milliseconds
    # Column name overrides — qeviz uses these instead of hardcoded column names.
    id_col      = "QEUNIT",
    node_id_col = "code",
    x_col       = dim_cols[1L],
    y_col       = dim_cols[2L],
    group_col   = group_col
  )

  # ── groups frame (Phase 3 API) ────────────────────────────────────────────
  # One row per group: mean position in dim_cols space, plus optional CI bounds.
  # Replaces the deprecated separate confidence frame.
  # qeviz renders this directly — no statistics are computed in the browser.
  if (!is.null(group_col) && group_col %in% names(pts)) {
    groups_unique <- unique(pts[[group_col]])

    means_rows <- lapply(groups_unique, function(g) {
      sub   <- pts[pts[[group_col]] == g, dim_cols, drop = FALSE]
      means <- colMeans(sub, na.rm = TRUE)
      as.data.frame(
        as.list(c(group = g, setNames(as.numeric(means), dim_cols))),
        stringsAsFactors = FALSE
      )
    })
    groups_df <- do.call(rbind, Filter(Negate(is.null), means_rows))

    # Merge in CI bounds when requested
    if (include_ci) {
      ci_df <- .vizena_group_ci(pts, group_col, dim_cols, conf_level)
      if (!is.null(ci_df)) {
        groups_df <- merge(groups_df, ci_df, by = "group", all.x = TRUE)
        # Restore the original group order (merge may reorder rows)
        groups_df <- groups_df[match(groups_unique, groups_df$group), , drop = FALSE]
      }
    }

    result$groups <- .ena_frame(groups_df)

    # @deprecated: outlier frame — kept for adapter versions not yet on Phase 4.
    # Will be removed once all consumers use the groups frame exclusively.
    out_df <- .vizena_group_outlier(pts, group_col, dim_cols, iqr_factor)
    if (!is.null(out_df)) result$outlier <- .ena_frame(out_df)
  }

  result
}


# ── Public API ────────────────────────────────────────────────────────────────

#' Plot an ENA set using the VizENA web component
#'
#' Renders an interactive ENA plot inside RStudio, R Markdown / Quarto, and
#' Shiny using the standalone VizENA visualization library.
#'
#' @param set         An \code{\link{ena.make.set}} result.
#' @param group_col   Character. Name of the grouping column in \code{set$points}
#'                    (e.g. \code{"Condition"}).  Controls point colours and group
#'                    mean networks.
#' @param group       Character. Which group's mean network to display.  Defaults
#'                    to the first group (alphabetical order).
#' @param unit        Character. A specific unit ID (the \code{ENA_UNIT} value,
#'                    e.g. \code{"steven z::FirstGame"}) to display its individual
#'                    network instead of a group mean.
#' @param compare     Character. Second group or unit for a subtraction view
#'                    (\code{group} minus \code{compare}).
#' @param also        Character. Second group for an overlay view (both networks
#'                    drawn simultaneously).
#' @param dim_cols    Character vector of two dimension names to plot.
#'                    Default \code{c("SVD1", "SVD2")}.
#' @param label_nodes  \code{"on"} | \code{"off"} | \code{"auto"} | \code{"click"}.
#'                    Visibility of code-node labels.  Default \code{"on"}.
#' @param label_means  Visibility of group-mean labels.  Default \code{"on"}.
#' @param label_points Visibility of unit-point labels.  Default \code{"off"}.
#' @param confidence  Logical. Draw 95\% CI boxes around group means. Default
#'                    \code{TRUE}.
#' @param outlier     Logical. Draw IQR-based outlier boxes. Default \code{TRUE}.
#' @param scale_points Logical. Rescale unit points to match the node coordinate
#'                    space.  Default \code{TRUE}.
#' @param conf_level  Numeric. Confidence level for CI boxes. Default \code{0.95}.
#' @param iqr_factor  Numeric. IQR multiplier for outlier boxes. Default \code{1.5}.
#' @param width,height Widget dimensions in pixels.  \code{NULL} uses the
#'                    htmlwidgets sizing policy defaults (700 × 650).
#'
#' @return An \code{htmlwidget} object that renders in RStudio Viewer, R Markdown,
#'   Quarto, and Shiny.
#'
#' @examples
#' \dontrun{
#' data(RS.data)
#' codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
#'                "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
#' accum <- ena.accumulate.data(
#'   units        = RS.data[, c("UserName", "Condition")],
#'   conversation = RS.data[, c("Condition", "GroupName")],
#'   codes        = RS.data[, codeNames],
#'   window.size.back = 4
#' )
#' set <- ena.make.set(enadata = accum)
#'
#' # Basic plot coloured by Condition
#' ena_plot_vizena(set, group_col = "Condition")
#'
#' # Show only FirstGame mean network
#' ena_plot_vizena(set, group_col = "Condition", group = "FirstGame")
#'
#' # Subtraction: FirstGame minus SecondGame
#' ena_plot_vizena(set, group_col = "Condition",
#'                 group = "FirstGame", compare = "SecondGame")
#' }
#'
#' @export
ena_plot_vizena <- function(
  set,
  group_col     = NULL,
  group         = NULL,
  unit          = NULL,
  compare       = NULL,
  also          = NULL,
  dim_cols      = c("SVD1", "SVD2"),
  label_nodes   = "on",
  label_means   = "on",
  label_points  = "off",
  confidence    = TRUE,
  outlier       = TRUE,
  scale_points  = TRUE,
  conf_level    = 0.95,
  iqr_factor    = 1.5,
  width         = NULL,
  height        = NULL
) {
  if (!requireNamespace("htmlwidgets", quietly = TRUE)) {
    stop("The 'htmlwidgets' package is required. Install it with: install.packages('htmlwidgets')")
  }

  model_data <- .ena_to_vizena_data(
    set,
    group_col  = group_col,
    dim_cols   = dim_cols,
    include_ci = isTRUE(confidence),
    conf_level = conf_level,
    iqr_factor = iqr_factor
  )

  x <- list(
    model   = model_data,
    options = list(
      group        = group,
      unit         = unit,
      compare      = compare,
      also         = also,
      labelNodes   = label_nodes,
      labelMeans   = label_means,
      labelPoints  = label_points,
      # confidence bounds are now in the groups frame, not a separate attribute.
      # outlier is still a separate deprecated frame; keep the escape-hatch attr.
      outlier      = if (isFALSE(outlier)) "false" else NULL,
      scalePoints  = if (isFALSE(scale_points)) "false" else NULL
    )
  )

  htmlwidgets::createWidget(
    name    = "vizena",
    x       = x,
    width   = width,
    height  = height,
    package = "rENA",
    sizingPolicy = htmlwidgets::sizingPolicy(
      viewer.padding      = 5,
      browser.fill        = TRUE,
      knitr.figure        = FALSE,
      knitr.defaultWidth  = 700,
      knitr.defaultHeight = 650
    )
  )
}

#' Shiny output binding for VizENA plots
#'
#' @param outputId Shiny output ID.
#' @param width,height CSS dimensions. Defaults: \code{"100\%"}, \code{"600px"}.
#' @export
vizenaOutput <- function(outputId, width = "100%", height = "600px") {
  htmlwidgets::shinyWidgetOutput(outputId, "vizena", width, height, package = "rENA")
}

#' Shiny render function for VizENA plots
#'
#' @param expr Expression that returns an \code{\link{ena_plot_vizena}} widget.
#' @param env  Environment for \code{expr}. Default: \code{parent.frame()}.
#' @param quoted Logical. Is \code{expr} already quoted? Default \code{FALSE}.
#' @export
renderVizena <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) expr <- substitute(expr)
  htmlwidgets::shinyRenderWidget(expr, vizenaOutput, env, quoted = TRUE)
}
