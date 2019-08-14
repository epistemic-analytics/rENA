#####
#' @title Wrapper to generate, and optionally plot, an ENA model
#'
#' @description Generates an ENA model by constructing a dimensional reduction
#' of adjacency (co-occurrence) vectors as defined by the supplied
#' conversations, units, and codes
#'
#' @details This function generates an ena.set object given a data.frame, units,
#' conversations, and codes. After accumulating the adjacency (co-occurrence)
#' vectors, computes a dimensional reduction (projection), and calculates node
#' positions in the projected ENA space. Returns location of the units in the
#' projected space, as well as locations for node positions, and normalized
#' adjacency (co-occurrence) vectors to construct network graphs
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
#' @param include.plots If TRUE, will generate plots based on the generated model
#' @param print.plots [TBD]
#' @param ... [TBD]
#'
#' @examples
#' data(RS.data)
#' 
#' rs = ena(
#'   data = RS.data,
#'   units = c("UserName","Condition", "GroupName"),
#'   conversation = c("Condition","GroupName"),
#'   codes = c('Data',
#'             'Technical.Constraints',
#'             'Performance.Parameters',
#'             'Client.and.Consultant.Requests',
#'             'Design.Reasoning',
#'             'Collaboration'),
#'   window.size.back = 4,
#'   print.plots = F,
#'   groupVar = "Condition",
#'   groups = c("FirstGame", "SecondGame")
#' )
#'
#' @return ena.set object
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
  include.plots = F,
  print.plots = T,
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
    mask = mask,
    include.meta = include.meta,
    groupVar = groupVar,
    groups = groups,
    runTest = runTest,
    testType = testType,
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
      showPlots = print.plots,
      ...
    )
  }

  return(set)
}
