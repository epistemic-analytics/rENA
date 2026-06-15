#####
#' @title Wrapper to generate, and optionally plot, an ENA model
#'
#' @description Convenience entry point for constructing an ENA model from a
#' coded data frame. Handles accumulation, dimensional reduction, and optional
#' plot generation in a single call, returning an \code{ena.set} object that
#' contains unit positions, network weights, node positions, and plots.
#'
#' @details
#' \code{ena()} runs three phases internally:
#'
#' \strong{1. Accumulation} — co-occurrence counts are computed for each unit
#' across stanza windows defined by \code{window}, \code{window.size.back}, and
#' \code{window.size.forward}.
#'
#' \strong{2. Dimensional reduction} — accumulated vectors are normed, centered,
#' and rotated into a low-dimensional ENA space. When \code{groupVar} and two
#' \code{groups} are supplied the rotation maximises separation between the group
#' means (means rotation); otherwise SVD is used.
#'
#' \strong{3. Plotting} — plots are built and stored on the returned set in
#' \code{set$plots}. Pass \code{include.plots = FALSE} to skip this phase
#' entirely, which is useful for programmatic use (simulations, parameter
#' sweeps) where plot objects are not needed.
#'
#' \strong{Plot defaults:} \code{network = TRUE} but \code{points = FALSE} and
#' \code{mean = FALSE}. For a two-group comparison you almost always want
#' \code{mean = TRUE} as well, to show group centroids and confidence intervals
#' alongside the network.
#'
#' \strong{Accessing results:} the returned \code{ena.set} object contains:
#' \describe{
#'   \item{\code{$points}}{unit positions in the rotated ENA space (rows = units)}
#'   \item{\code{$line.weights}}{normed co-occurrence weights per unit (rows = units, cols = code pairs)}
#'   \item{\code{$node.positions}}{positions of each code node in the ENA space}
#'   \item{\code{$plots}}{named list of \code{ENAplot} objects; two-group models
#'     produce three plots keyed by \code{group1}, \code{group2}, and
#'     \code{"group1-group2"}}
#'   \item{\code{$tests}}{list of Wilcoxon and t-test results on dimensions 1
#'     and 2, populated when \code{runTest = TRUE}}
#'   \item{\code{$variance}}{proportion of variance explained by each dimension}
#' }
#'
#' @param data data.frame containing metadata and coded columns
#' @param codes vector, numeric or character, of column names or indices containing the codes to model
#' @param units vector, numeric or character, of column names that together uniquely identify each unit of analysis
#' @param conversation vector, numeric or character, of column names used to segment the data into conversations (stanza boundaries reset at each new conversation)
#' @param metadata vector, numeric or character, of column names to carry through as unit-level metadata (default: NULL)
#' @param model character, the ENA model to construct: \code{EndPoint} (default) produces a single adjacency vector per unit summing co-occurrences across all lines; \code{AccumulatedTrajectory} produces one adjacency vector per unit per conversation, where each successive conversation accumulates prior ones; \code{SeparateTrajectory} produces one adjacency vector per unit per conversation, each modeled independently
#' @param weight.by how to weight co-occurrences: \code{"binary"} (default) counts each co-occurrence once per stanza window; supply a function (e.g. \code{sum}) to use raw counts
#' @param window stanza window type: \code{"MovingStanzaWindow"} (default) or \code{"Conversation"} (all lines in a conversation form one window)
#' @param window.size.back integer, number of lines back from each line to include in the stanza window (default: 1)
#' @param window.size.forward integer, number of lines forward from each line to include in the stanza window (default: 0). Set to model bidirectional co-occurrence within a window.
#' @param include.meta logical, if TRUE (default) unit metadata is attached to the resulting ENAdata object and accessible via the set; set to FALSE to omit metadata from the model output
#' @param groupVar character, name of the column containing group labels. When supplied with two \code{groups}, the model uses a means rotation that maximises variance between group means.
#' @param groups vector, character, of exactly the group values from \code{groupVar} to use for means rotation, plotting, and statistical tests. If omitted, the first two unique values of \code{groupVar} are used with a warning.
#' @param runTest logical, if TRUE runs a Wilcoxon rank-sum test and a Student's t-test comparing the two groups on dimensions 1 and 2; results stored in \code{set$tests} (default: FALSE)
#' @param points logical, TRUE will plot individual unit points (default: FALSE)
#' @param mean logical, TRUE will plot group mean positions with confidence intervals — recommended whenever \code{groupVar} is supplied (default: FALSE)
#' @param network logical, TRUE will plot mean networks (default: TRUE)
#' @param networkMultiplier numeric, scaling factor applied to edge weights in non-subtracted network plots (default: 1)
#' @param subtractionMultiplier numeric, scaling factor applied to edge weights in the subtracted network plot (default: 1)
#' @param unit character, name of a single unit to plot in isolation; when supplied, all group plotting is skipped
#' @param colors vector, character, of colors for groups or points. For two-group models, supply two values (group1, group2); for single-group or no-group models, supply one value. Defaults to "blue"/"red" for two groups and "black" otherwise.
#' @param confidence.interval character, style of confidence interval shown on mean points: "box" (default), "crosshairs", or "none"
#' @param include.plots logical, if TRUE (default) generates and attaches plot objects to the returned set; set to FALSE to skip all plotting for faster programmatic use
#' @param print.plots logical, if TRUE renders plots in the Viewer as they are created (default: FALSE)
#' @param ... Additional parameters passed to set creation and plotting functions, including \code{mask} (an optional binary matrix of size ncol(codes) x ncol(codes) where 0 suppresses co-occurrence modeling between a pair of codes; see \code{\link{ena.accumulate.data}})
#'
#' @examples
#' data(RS.data)
#'
#' codes = c('Data',
#'           'Technical.Constraints',
#'           'Performance.Parameters',
#'           'Client.and.Consultant.Requests',
#'           'Design.Reasoning',
#'           'Collaboration')
#'
#' # Minimal call: fit a model with no group comparison
#' rs = ena(
#'   data = RS.data,
#'   units = c("UserName", "Condition", "GroupName"),
#'   conversation = c("Condition", "GroupName"),
#'   codes = codes,
#'   window.size.back = 4
#' )
#'
#' # Two-group comparison with means rotation, centroids, and statistical tests
#' rs = ena(
#'   data = RS.data,
#'   units = c("UserName", "Condition", "GroupName"),
#'   conversation = c("Condition", "GroupName"),
#'   codes = codes,
#'   window.size.back = 4,
#'   groupVar = "Condition",
#'   groups = c("FirstGame", "SecondGame"),
#'   mean = TRUE,
#'   runTest = TRUE,
#'   print.plots = FALSE
#' )
#'
#' # Model fitting only, no plots (faster for programmatic use)
#' rs = ena(
#'   data = RS.data,
#'   units = c("UserName", "Condition", "GroupName"),
#'   conversation = c("Condition", "GroupName"),
#'   codes = codes,
#'   window.size.back = 4,
#'   include.plots = FALSE
#' )
#'
#' @return An \code{ena.set} object. See the Details section for a description
#'   of the key fields (\code{$points}, \code{$line.weights}, \code{$plots},
#'   \code{$tests}, etc.).
#' @export
#####
ena <- function(
  data,
  codes,
  units,
  conversation,
  metadata = NULL,
  model = c("EndPoint", "AccumulatedTrajectory", "SeparateTrajectory"),
  weight.by = "binary",
  window = c("MovingStanzaWindow", "Conversation"),
  window.size.back = 1,
  window.size.forward = 0,
  include.meta = TRUE,
  groupVar = NULL,
  groups = NULL,
  runTest = FALSE,
  points = FALSE,
  mean = FALSE,
  network = TRUE,
  networkMultiplier = 1,
  subtractionMultiplier = 1,
  unit = NULL,
  colors = NULL,
  confidence.interval = "box",
  include.plots = T,
  print.plots = F,
  ...
) {
  set <- ena.set.creator(
    data = data,
    codes = codes,
    units = units,
    conversation = conversation,
    metadata = metadata,
    model = model,
    weight.by = weight.by,
    window = window,
    window.size.back = window.size.back,
    window.size.forward = window.size.forward,
    include.meta = include.meta,
    groupVar = groupVar,
    groups = groups,
    runTest = runTest,
    ...
  )

  if (include.plots) {
    set <- ena.plotter(
      set = set,
      groupVar = groupVar,
      groups = groups,
      points = points,
      mean = mean,
      network = network,
      networkMultiplier = networkMultiplier,
      subtractionMultiplier = subtractionMultiplier,
      unit = unit,
      colors = colors,
      confidence.interval = confidence.interval,
      print.plots = print.plots,
      ...
    )
  }

  return(set)
}
