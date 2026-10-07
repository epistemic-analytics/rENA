## ── qeviz interactive plot integration ───────────────────────────────────────
##
## Public API (thin wrappers over the qeviz package)
##   ena.plot.interactive()   — create an interactive qeviz htmlwidget
##   ena.export.html()        — write a self-contained HTML file
##   enaInteractiveOutput()   — Shiny output binding
##   renderEnaInteractive()   — Shiny render function
##
## The widget, its JavaScript bundle and the ena.set -> ModelData conversion
## live in qeviz (qe_plot(), qe_widget(), qeOutput(), renderQe()).
## ─────────────────────────────────────────────────────────────────────────────


.require_qeviz <- function() {
  if (!requireNamespace("qeviz", quietly = TRUE) || utils::packageVersion("qeviz") < "0.5.0") {
    stop("The 'qeviz' package (>= 0.5.0) is required for interactive plots. Install with:\n",
         "  install.packages(\"qeviz\", repos = c(\"https://cran.qe-libs.org\", getOption(\"repos\")))",
         call. = FALSE)
  }
}

#' Interactive ENA plot using qeviz
#'
#' Renders an interactive ENA plot inside RStudio, R Markdown / Quarto, and
#' Shiny using the qeviz visualization library. This is a shortcut for a
#' \code{qeviz::qe_plot()} chain; use qeviz directly for full control.
#'
#' @param set         An \code{\link{ena.make.set}} result.
#' @param group_col   Character. Name of the grouping column in \code{set$points}
#'                    (e.g. \code{"Condition"}).  Controls point colours and group
#'                    mean networks.
#' @param group       Character. Which group's mean network to display.  Defaults
#'                    to the first group.
#' @param unit        Character. A specific unit ID to display its individual
#'                    network instead of a group mean.
#' @param compare     Character. Second group or unit for a subtraction view
#'                    (\code{group} minus \code{compare}).
#' @param also        Character. Second group for an overlay view (both networks
#'                    drawn simultaneously).
#' @param dim_cols    Character vector of two dimension names to plot.
#'                    Default \code{c("SVD1", "SVD2")}.
#' @param label_nodes \code{"on"} | \code{"off"} | \code{"auto"} | \code{"click"}.
#'                    Visibility of code-node labels.  Default \code{"on"}.
#' @param label_means Visibility of group-mean labels.  Default \code{"on"}.
#' @param label_points Visibility of unit-point labels.  Default \code{"off"}.
#' @param confidence  Logical. Draw the confidence interval box around each
#'                    shown group mean. Default \code{TRUE}.
#' @param outlier     Logical. Also draw the outlier interval (Q1 - 1.5 IQR to
#'                    Q3 + 1.5 IQR). Default \code{FALSE}.
#' @param scale_points Logical. Rescale unit points to match the node coordinate
#'                    space.  Default \code{TRUE}.
#' @param conf_level  Numeric. Confidence level for CI boxes. Default \code{0.95}.
#' @param iqr_factor  Deprecated; the outlier interval always uses 1.5 IQR.
#' @param width,height Widget size in pixels or CSS units.  \code{NULL} uses
#'                    the qeviz defaults (100\% x 440).
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
#' ena.plot.interactive(set, group_col = "Condition")
#'
#' # Show only FirstGame mean network
#' ena.plot.interactive(set, group_col = "Condition", group = "FirstGame")
#'
#' # Subtraction: FirstGame minus SecondGame
#' ena.plot.interactive(set, group_col = "Condition",
#'                      group = "FirstGame", compare = "SecondGame")
#' }
#'
#' @export
ena.plot.interactive <- function(
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
  outlier       = FALSE,
  scale_points  = TRUE,
  conf_level    = 0.95,
  iqr_factor    = 1.5,
  width         = NULL,
  height        = NULL
) {
  .require_qeviz()
  if (!missing(iqr_factor) && !identical(iqr_factor, 1.5))
    warning("ena.plot.interactive(): iqr_factor is deprecated and ignored; ",
            "the outlier interval uses 1.5 IQR.", call. = FALSE)

  p <- qeviz::qe_plot(set, dims = dim_cols, scale_points = scale_points,
                      group_col = group_col,
                      width  = if (is.null(width)) "100%" else width,
                      height = if (is.null(height)) 440 else height)

  # A group mean network: the requested group, else the first group (as
  # before). A unit network is drawn instead when `unit` is given.
  groups <- if (is.null(group_col)) character(0)
            else unique(as.character(as.data.frame(set$points)[[group_col]]))
  if (is.null(group) && is.null(unit) && length(groups)) group <- groups[1L]
  if (!is.null(group) || !is.null(unit))
    p <- qeviz::qe_edges(p, group = group, unit = unit, compare = compare, also = also)

  # Means (with CI) for the groups whose networks are shown.
  # Means (with CI) for the groups whose networks are shown; none otherwise.
  shown <- intersect(c(group, compare, also), groups)
  p <- if (length(shown))
    do.call(qeviz::qe_group, c(list(p), as.list(shown), list(
      intervals  = if (isTRUE(confidence)) "box" else "none",
      conf_level = conf_level,
      outlier    = isTRUE(outlier))))
  else qeviz::qe_group(p, show = FALSE)

  p <- qeviz::qe_axes(p)
  p <- qeviz::qe_labels(p, nodes = label_nodes, means = label_means, points = label_points)
  qeviz::qe_widget(p)
}

#' Export a self-contained interactive ENA plot as HTML
#'
#' Writes a single \code{.html} file containing the qeviz bundle and embedded
#' model data.  No R, no Python, and no server are required to open the file —
#' share it with collaborators, attach it to a paper submission, or archive it
#' as supplementary material.
#'
#' @param set       An \code{\link{ena.make.set}} result.
#' @param file      Output file path, e.g. \code{"ena_plot.html"}.
#' @param group_col Character. Grouping column in \code{set$points}.
#' @param ...       Additional arguments passed to \code{\link{ena.plot.interactive}}
#'                  (e.g. \code{group}, \code{compare}, \code{label_nodes}).
#' @param width,height Plot dimensions in pixels. Default 700 × 600.
#' @param selfcontained Logical. Inline the qeviz bundle in the HTML file.
#'                    Default \code{TRUE}.  Set to \code{FALSE} to reference the
#'                    bundle via a relative path (smaller file, not portable).
#'
#' @return The resolved absolute path of the written file (invisibly).
#'
#' @examples
#' \dontrun{
#' set <- ena.make.set(enadata = accum)
#' ena.export.html(set, "model.html", group_col = "Condition")
#' }
#'
#' @export
ena.export.html <- function(
  set,
  file,
  group_col     = NULL,
  ...,
  width         = 700L,
  height        = 600L,
  selfcontained = TRUE
) {
  widget <- ena.plot.interactive(
    set,
    group_col = group_col,
    width     = width,
    height    = height,
    ...
  )
  abs_file <- normalizePath(file, mustWork = FALSE)
  htmlwidgets::saveWidget(widget, abs_file, selfcontained = selfcontained)
  message("Written: ", abs_file)
  invisible(abs_file)
}

#' Shiny output binding for interactive ENA plots
#'
#' Equivalent to \code{qeviz::qeOutput()}.
#'
#' @param outputId Shiny output ID.
#' @param width,height CSS dimensions. Defaults: \code{"100\%"}, \code{"600px"}.
#' @export
enaInteractiveOutput <- function(outputId, width = "100%", height = "600px") {
  .require_qeviz()
  qeviz::qeOutput(outputId, width = width, height = height)
}

#' Shiny render function for interactive ENA plots
#'
#' Equivalent to \code{qeviz::renderQe()}; \code{expr} may return an
#' \code{\link{ena.plot.interactive}} widget or a \code{qeviz::qe_plot()}.
#'
#' @param expr    Expression that returns an \code{\link{ena.plot.interactive}} widget.
#' @param env     Environment for \code{expr}. Default: \code{parent.frame()}.
#' @param quoted  Logical. Is \code{expr} already quoted? Default \code{FALSE}.
#' @export
renderEnaInteractive <- function(expr, env = parent.frame(), quoted = FALSE) {
  .require_qeviz()
  if (!quoted) expr <- substitute(expr)
  qeviz::renderQe(expr, env = env, quoted = TRUE)
}
