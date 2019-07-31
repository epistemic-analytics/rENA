#' ena wrapper function
#'
#' @param data [TBD]
#' @param codes [TBD]
#' @param units [TBD]
#' @param conversation [TBD]
#' @param metadata [TBD]
#' @param model [TBD]
#' @param weight.by [TBD]
#' @param window [TBD]
#' @param window.size.back [TBD]
#' @param window.size.forward [TBD]
#' @param mask [TBD]
#' @param include.meta [TBD]
#' @param groupVar [TBD]
#' @param groups [TBD]
#' @param runTest [TBD]
#' @param testType [TBD]
#' @param points [TBD]
#' @param mean [TBD]
#' @param network [TBD]
#' @param networkMultiplier [TBD]
#' @param subtractionMultiplier [TBD]
#' @param unit [TBD]
#' @param show.plots [TBD]
#' @param include.plots [TBD]
#' @param ... [TBD]
#'
#' @return ena.set object
#' @export
ena = function(
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
  mask = NULL,
  include.meta = TRUE,
  groupVar = NULL,
  groups = NULL,
  runTest = FALSE,
  testType = c("nonparametric","parametric"),
  points = FALSE,
  mean = FALSE,
  network = TRUE,
  networkMultiplier = 1,
  subtractionMultiplier = 1,
  unit = NULL,
  show.plots = F,
  include.plots = T,
  ...
) {
  set = ena.set.creator(
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
    mask = mask,
    include.meta = include.meta,
    groupVar = groupVar,
    groups = groups,
    runTest = runTest,
    testType = testType,
    ...
  )

  if(include.plots) {
    set = ena.plotter(
      set = set,
      groupVar = groupVar,
      groups = groups,
      points = points,
      mean = mean,
      network = network,
      networkMultiplier = networkMultiplier,
      subtractionMultiplier = subtractionMultiplier,
      unit = unit,
      showPlots = show.plots,
      ...
    )

  }

  return(set)
}
