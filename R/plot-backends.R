#' @title Plot backends: plotly and qeviz
#'
#' @name rENA-plot-backends
#' @aliases plot.backends rENA.plot.backend
#'
#' @description rENA draws plots with one of two backends. \strong{plotly} is
#'   the default. \strong{qeviz} (>= 0.5.0, from \url{https://cran.qe-libs.org};
#'   a suggested package) draws the same plots with qeviz, the library behind
#'   webENA's network plots, and returns a qeviz htmlwidget.
#'
#' @section Choosing a backend:
#' Per plot, with \code{ena.plot(set, backend = "qeviz")}, or for the session
#' with \code{options(rENA.plot.backend = "qeviz")}. \code{\link{ena.plotter}}
#' and \code{\link{ena.plot.subtraction}} take \code{backend} too and pass it
#' to every plot they create.
#'
#' Existing plotting code works unchanged on either backend:
#' \code{\link{ena.plot.network}}, \code{\link{ena.plot.points}},
#' \code{\link{ena.plot.group}}, and the pipe API (\code{add_network()},
#' \code{add_points()}, \code{add_group()}, \code{with_means()},
#' \code{check_range()}, \code{show()}) add layers to whichever backend the
#' plot was created with.
#'
#' @section What differs on qeviz:
#' \itemize{
#'   \item \code{$plot} is a qeviz htmlwidget, not a plotly object, so code
#'     that edits it with \code{plotly::layout()} or other plotly functions
#'     does not apply. \code{print()} shows it as before.
#'   \item \strong{Scaling.} Line width is absolute per weight, colour
#'     intensity is scaled across the whole model, and a node's size is the
#'     sum of its edge widths. Separate plots of one model are therefore
#'     directly comparable. \code{thickness}, \code{opacity},
#'     \code{saturation}, \code{scale.range}, \code{scale.weights} and
#'     \code{node.size} are ignored.
#'   \item \strong{Multipliers.} \code{ena.plot(multiplier =)},
#'     \code{add_network(edge.multiplier =)}, and the \code{ena.plotter()}
#'     and \code{ena.plot.subtraction()} multipliers magnify the drawn network
#'     rather than multiplying the weights. \code{ena.plotter()} and
#'     \code{ena.plot.subtraction()} label their plots "(scaled Nx)".
#'   \item \strong{Point size.} \code{point.size} is halved to match qeviz's
#'     units, so the default sizes look the same.
#'   \item \strong{Means.} Each \code{ena.plot.group()} call keeps its own
#'     confidence and outlier intervals. An outlier interval drawn as
#'     \code{"crosshairs"} is drawn as a box. \code{method} must be
#'     \code{"mean"}.
#'   \item \strong{Ranges} are symmetric: \code{scale.to} is
#'     \code{"network"}, \code{"points"} or a number;
#'     \code{list(x =, y =)} is an error.
#'   \item \strong{Default palette} is Paul Tol's "bright"
#'     (\code{qeviz::qe_palette()}). Colours you pass are used as given.
#' }
#'
#' @section Not available on qeviz:
#' Trajectories and movies (\code{\link{ena.plot.trajectory}},
#' \code{add_trajectory()}, \code{\link{ena.plot.movie}},
#' \code{with_trajectory()}) warn with class \code{rENA_qeviz_unsupported}
#' and return the plot unchanged; use \code{backend = "plotly"} for them.
#' Dashed or dotted edges, label offsets, legends and per-point confidence or
#' outlier intervals are not drawn.
#'
#' Arguments that would change the picture but cannot be honoured warn once
#' per session. Plotly-only layout options (\code{showticklabels},
#' \code{ticks}, \code{axispadding}, \code{autosize}, \code{automargin},
#' \code{displayModeBar}) are ignored without a warning.
#'
#' @examples
#' if (requireNamespace("qeviz", quietly = TRUE) &&
#'     utils::packageVersion("qeviz") >= "0.5.0") {
#'   data(RS.data)
#'   codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
#'     "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
#'   accum <- ena.accumulate.data(
#'     units = RS.data[, c("Condition", "UserName")],
#'     conversation = RS.data[, c("Condition", "GroupName")],
#'     codes = RS.data[, codeNames],
#'     window.size.back = 4
#'   )
#'   set <- ena.make.set(accum)
#'   first <- set$meta.data$Condition == "FirstGame"
#'
#'   plot <- ena.plot(set, title = "FirstGame", backend = "qeviz")
#'   plot <- ena.plot.network(plot, network = colMeans(as.matrix(set$line.weights[first, ])))
#'   plot <- ena.plot.group(plot, as.matrix(set$points[first, ]), labels = "FirstGame",
#'                          confidence.interval = "box")
#'   print(plot)
#' }
#'
#' @seealso \code{\link{ena.plot}}, \code{\link{ena.plotter}},
#'   \code{\link{ena.plot.interactive}}
NULL
