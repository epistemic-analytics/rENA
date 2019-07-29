### ena wrapper function ###


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
  showPlots = F,
  ...
){

  set = ena.set.creator(data = data,
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
                        ...)



  set = ena.plotter(set = set,
                    groupVar = groupVar,
                    groups = groups,
                    points = points,
                    mean = mean,
                    network = network,
                    networkMultiplier = networkMultiplier,
                    subtractionMultiplier = subtractionMultiplier,
                    unit = unit,
                    showPlots = showPlots)

  return(set)

}
