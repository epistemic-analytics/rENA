## ── qeviz backend for the ena.plot.* layer functions ─────────────────────────
##
## With ena.plot(backend = "qeviz"), ena.plot.network() / ena.plot.points() /
## ena.plot.group() hand off to the functions here, which add layers to the
## ENAplot's qeviz::qe_plot() ($qe) instead of plotly traces. The mapping is
## documented in qeviz's docs/rena-qeviz-backend.md.
##
## Arguments qeviz cannot honour warn once per session when they change the
## picture (see .qe_ignored()); plotly-only layout options are ignored quietly.
## ─────────────────────────────────────────────────────────────────────────────

.qe_backend <- function(enaplot) {
  !is.null(enaplot) && is(enaplot, "ENAplot") && identical(enaplot$get("backend"), "qeviz")
}

.qe_warned <- new.env(parent = emptyenv())

# Warn once per session for each supplied argument qeviz ignores.
.qe_ignored <- function(fn, supplied, args, why) {
  for (a in intersect(args, supplied)) {
    key <- paste(fn, a, sep = "::")
    if (isTRUE(.qe_warned[[key]])) next
    assign(key, TRUE, envir = .qe_warned)
    warning(sprintf("%s(): '%s' is ignored on the qeviz backend (%s).", fn, a, why),
            call. = FALSE)
  }
}

# Colours as hex (qeviz derives complements from hex; rENA passes names / I()).
.qe_hex <- function(colors) {
  if (is.null(colors)) return(NULL)
  cols <- as.character(unclass(colors))
  m <- grDevices::col2rgb(cols, alpha = FALSE)
  stats::setNames(grDevices::rgb(m[1, ], m[2, ], m[3, ], maxColorValue = 255), names(colors))
}

# Plot-wide label fonts, applied only when a layer call supplied them.
.qe_fonts <- function(qe, supplied, size, family, color) {
  args <- list(qe)
  if ("label.font.size" %in% supplied)   args$font_size   <- size
  if ("label.font.family" %in% supplied) args$font_family <- family
  if ("label.font.color" %in% supplied)  args$font_color  <- color
  if (length(args) > 1) do.call(qeviz::qe_labels, args) else qe
}

# Points in rENA's accepted forms (ena.points, data.frame / matrix, a numeric
# vector for one point) -> id + the first two dimension columns, named as the
# model's axes so qeviz reads them.
.qe_point_df <- function(points, enaplot, ids = NULL) {
  m <- enaplot$qe$model
  if (is.numeric(points) && is.null(dim(points))) points <- matrix(points, nrow = 1)
  unit <- if (!is.null(ids)) as.character(ids)
          else if (is.data.frame(points) && "ENA_UNIT" %in% names(points)) as.character(points$ENA_UNIT)
          else if (!is.null(rownames(points))) rownames(points)
          else NULL
  dims <- as.data.frame(if (is(points, "ena.points") || is.data.table(points)) remove_meta_data(points)
                        else points, check.names = FALSE)
  dims <- dims[, vapply(dims, is.numeric, logical(1)), drop = FALSE]
  if (ncol(dims) < 2) stop("points need at least two dimension columns.", call. = FALSE)
  out <- data.frame(id = if (is.null(unit)) as.character(seq_len(nrow(dims))) else unit,
                    stringsAsFactors = FALSE)
  names(out) <- m$id_col
  out[[m$x_col]] <- as.numeric(dims[[1]])
  out[[m$y_col]] <- as.numeric(dims[[2]])
  out
}

# ── ena.plot.network ─────────────────────────────────────────────────────────
.qe_plot_network <- function(enaplot, supplied, network, node.positions, adjacency.key,
                             colors, edge_type, show.all.nodes, threshold,
                             thin.lines.in.front, layers, labels,
                             label.font.size, label.font.color, label.font.family,
                             legend.name, dots) {
  fn <- "ena.plot.network"
  .qe_ignored(fn, supplied,
              c("thickness", "opacity", "saturation", "scale.range", "node.size", "scale.weights"),
              "qeviz's model-wide width and colour scaling replaces them")
  .qe_ignored(fn, supplied, c("label.offset", "legend.include.edges"), "not supported")
  if ("edge_type" %in% supplied && !identical(edge_type, "line"))
    .qe_ignored(fn, "edge_type", "edge_type", "edges are always solid lines")
  if ("thin.lines.in.front" %in% supplied && isFALSE(thin.lines.in.front))
    .qe_ignored(fn, "thin.lines.in.front", "thin.lines.in.front", "thin lines are always drawn on top")

  qe <- enaplot$qe
  if (is.data.frame(network) || is.matrix(network)) {
    nw <- as.data.frame(network, check.names = FALSE)
    network <- colMeans(as.matrix(nw[, vapply(nw, is.numeric, logical(1)), drop = FALSE]))
  }
  network <- stats::setNames(as.numeric(unclass(network)), names(network))
  # Same length rule as the plotly path: one weight per pair of nodes.
  n_nodes <- NROW(node.positions)
  if (length(network) != choose(n_nodes, 2))
    stop(paste0("Network vector needs to be of length ", choose(n_nodes, 2)), call. = FALSE)
  # Unnamed weights follow the adjacency key, exactly as the plotly path reads
  # them: the key given, else the one implied by node.positions' codes.
  if (!is.null(adjacency.key) || is.null(names(network))) {
    codes <- if (is(node.positions, "ena.nodes")) as.character(node.positions$code)
             else rownames(node.positions)
    key <- as.matrix(if (!is.null(adjacency.key)) adjacency.key else namesToAdjacencyKey(codes))
    names(network) <- paste(key[1, ], key[2, ], sep = " & ")
  }

  if ("node.positions" %in% supplied)
    qe <- qeviz::qe_nodes(qe, positions = node.positions)
  if ("labels" %in% supplied && !is.null(labels)) {
    codes <- if (is(node.positions, "ena.nodes")) as.character(node.positions$code)
             else rownames(node.positions)
    qe <- qeviz::qe_nodes(qe, labels = stats::setNames(as.character(labels), codes))
  }
  show <- if (!"edges" %in% layers) "always" else if (!"nodes" %in% layers) "never" else "auto"
  qe <- qeviz::qe_nodes(qe, show = show, unconnected = if (isFALSE(show.all.nodes)) "hide" else "dot")
  if (isTRUE(dots$labels.hide)) qe <- qeviz::qe_labels(qe, nodes = "off")

  thr <- threshold[is.finite(threshold)]
  if (!length(thr) || (length(thr) == 1 && thr[1] <= 0)) thr <- NULL
  mult <- enaplot$get("multiplier")
  if ("edges" %in% layers)
    qe <- qeviz::qe_edges(qe, weights = network, colors = unname(.qe_hex(colors)),
                          threshold = thr, name = legend.name,
                          magnify = if (!is.null(mult) && mult != 5) mult / 5)
  enaplot$qe <- .qe_fonts(qe, supplied, label.font.size, label.font.family, label.font.color)
  enaplot
}

# ── ena.plot.points ──────────────────────────────────────────────────────────
.qe_plot_points <- function(enaplot, supplied, points, point.size, labels, shape, colors,
                            label.font.size, label.font.color, label.font.family, texts) {
  fn <- "ena.plot.points"
  .qe_ignored(fn, supplied, c("confidence.interval.values", "outlier.interval.values",
                              "confidence.interval", "outlier.interval"),
              "per-point intervals are not supported; use ena.plot.group() for means")
  .qe_ignored(fn, supplied, c("label.offset", "label.group", "show.legend", "legend.name"),
              "not supported")
  if (is.null(points)) points <- enaplot$enaset$points
  df <- .qe_point_df(points, enaplot,
                     ids = if (!is.null(labels) && length(labels) == NROW(points) &&
                               !(is.numeric(points) && is.null(dim(points)))) labels)
  qe <- qeviz::qe_points(enaplot$qe, points = df,
                         color = unname(.qe_hex(colors)),
                         shape = if ("shape" %in% supplied) shape,
                         labels = if (!is.null(texts)) as.character(texts),
                         size = if ("point.size" %in% supplied) point.size / 2)
  enaplot$qe <- .qe_fonts(qe, supplied, label.font.size, label.font.family, label.font.color)
  enaplot
}

# ── ena.plot.group ───────────────────────────────────────────────────────────
.qe_plot_group <- function(enaplot, supplied, points, method, labels, colors, shape,
                           confidence.interval, outlier.interval,
                           label.font.size, label.font.color, label.font.family) {
  fn <- "ena.plot.group"
  if (!is.null(method) && !identical(method, "mean"))
    stop("ena.plot.group(): only method = \"mean\" is supported on the qeviz backend.",
         call. = FALSE)
  if (is.null(points)) stop("Points must be provided.")
  .qe_ignored(fn, supplied, c("label.offset", "show.legend", "legend.name"), "not supported")
  if (identical(outlier.interval, "crosshairs"))
    .qe_ignored(fn, "outlier.interval", "outlier.interval",
                "crosshairs are not available for the outlier interval; it is drawn as a box")

  df <- .qe_point_df(points, enaplot)
  cols <- if ("colors" %in% supplied) .qe_hex(colors)
  # rENA draws one mean per distinct colour when colors is given per point.
  split <- if (length(cols) == nrow(df) && length(unique(cols)) > 1) unique(cols) else NULL
  groups <- if (is.null(split)) list(list(rows = seq_len(nrow(df)), color = cols[1], label = labels[1]))
            else lapply(seq_along(split), function(k)
              list(rows = which(cols == split[k]), color = split[k],
                   label = if (length(labels) >= k) labels[k]))
  qe <- enaplot$qe
  for (g in groups) {
    sub <- df[g$rows, , drop = FALSE]
    qe <- qeviz::qe_group(qe, points = sub, label = g$label, color = unname(g$color),
                          shape = shape,
                          intervals = if (nrow(sub) < 2) "none" else confidence.interval,
                          outlier = nrow(sub) >= 2 && outlier.interval != "none")
  }
  enaplot$qe <- .qe_fonts(qe, supplied, label.font.size, label.font.family, label.font.color)
  enaplot
}
