#####
#' Wrapper for making ENA sets
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
#' @param ... [TBD]
#'
#' @return ena.set object
#####
ena.set.creator = function(
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
  ...
) {
  model = match.arg(model)
  window = match.arg(window)
  testType = match.arg(testType)

  accum = ena.accumulate.data(
    units = data[,units],
    conversation = data[,conversation],
    metadata = data[,metadata],
    codes = data[,codes],
    window = window,
    window.size.back = window.size.back,
    window.size.forward = window.size.forward,
    weight.by = weight.by,
    model = model,
    mask = mask,
    include.meta = include.meta,
    ...
  );

  ### make set if no group column is specified
  if(is.null(groupVar)) {
    set = ena.make.set(
      enadata = accum
    )

    if(runTest == TRUE){
      warning("Group variable and groups not specified. Unable to run test")
    }

    set$model$tests = NULL

    return(set)
  }

  ### make set if group column is specified, but groups are not
  else if(is.null(groups) == TRUE) {
    unique.groups = unique(data[,groupVar])

    if(length(unique.groups) == 1) {
      warning("Group variable only contains one unique value. ENAset has been created without means rotation")

      set = ena.make.set(
        enadata = accum
      )

      if(runTest == TRUE) {
        warning("Multiple groups not specified. Unable to run test ")
      }

      set$model$tests = NULL

      return(set)
    }

    else{

      group1 = unique.groups[1]
      group2 = unique.groups[2]

      warning(paste0("No groups specified. Defaulting to means rotation using first two unique group values of group variable: ",group1," and ",group2))

      set = ena.make.set(
        enadata = accum,
        rotation.by = ena.rotate.by.mean,
        rotation.params = list(accum$meta.data[[groupVar]] == group1, accum$meta.data[[groupVar]] == group2)
      )

      if(runTest == TRUE) {
        warning(paste0("No groups specified. Running test on the first two unique group values of the group variable: ",group1," and ",group2))

        group1.rows = set$points[[groupVar]] == group1
        group2.rows = set$points[[groupVar]] == group2

        group1.dim1 = as.matrix(set$points)[group1.rows,1]
        group2.dim1 =  as.matrix(set$points)[group2.rows,1]

        group1.dim2 = as.matrix(set$points)[group1.rows,2]
        group2.dim2 = as.matrix(set$points)[group2.rows,2]

        if(testType == "nonparametric") {
          test.dim1 = wilcox.test(x = group1.dim1, y = group2.dim1)
          test.dim2 = wilcox.test(x = group1.dim2, y = group2.dim2)
        }
        else {
          test.dim1 = t.test(x = group1.dim1, y = group2.dim1)
          test.dim2 = t.test(x = group1.dim2, y = group2.dim2)
        }

        set$model$tests = list(test.dim1,test.dim2)

        return(set)
      }
      else {
        set$model$tests = NULL

        return(set)
      }
    }
  }
  else if(length(groups) == 1) {
    warning("Only one group value specified. ENAset has been created without means rotation")

    set = ena.make.set(
      enadata = accum
    )

    if(runTest == TRUE) {
      warning("Multiple groups not specified. Unable to run test")
    }

    set$model$tests = NULL

    return(set)
  }
  else if(length(groups) > 2) {
    group1 = groups[1]
    group2 = groups[2]

    warning(paste0("Only two groups are allowed for means rotation. ENAset has been created using a means rotation on the first two groups given: ",group1," and ",group2))

    if(any(data[,groupVar] == group1) == FALSE){
      stop("Group column does not contain group1 value!")
    }

    if(any(data[,groupVar] == group2) == FALSE){
      stop("Group column does not contain group2 value!")
    }

    set = ena.make.set(
      enadata = accum,
      rotation.by = ena.rotate.by.mean,
      rotation.params = list(accum$meta.data[[groupVar]] == group1, accum$meta.data[[groupVar]] == group2)
    )

    if(runTest == TRUE) {
      warning(paste0("More than two groups specified. Running test on the first two groups: ",group1," and ",group2))

      group1.rows = set$points[[groupVar]] == group1
      group2.rows = set$points[[groupVar]] == group2

      group1.dim1 = as.matrix(set$points)[group1.rows,1]
      group2.dim1 =  as.matrix(set$points)[group2.rows,1]

      group1.dim2 = as.matrix(set$points)[group1.rows,2]
      group2.dim2 = as.matrix(set$points)[group2.rows,2]

      if(testType == "nonparametric") {
        test.dim1 = wilcox.test(x = group1.dim1, y = group2.dim1)
        test.dim2 = wilcox.test(x = group1.dim2, y = group2.dim2)
      }
      else {
        test.dim1 = t.test(x = group1.dim1, y = group2.dim1)
        test.dim2 = t.test(x = group1.dim2, y = group2.dim2)
      }

      set$model$tests = list(test.dim1,test.dim2)
      return(set)
    }
    else {
      set$model$tests = NULL

      return(set)
    }
  }

  ### make set if group column and two groups are specified
  else {
    group1 = groups[1]
    group2 = groups[2]

    if(any(data[,groupVar] == group1) == FALSE){
      stop("Group column does not contain group1 value!")
    }

    if(any(data[,groupVar] == group2) == FALSE){
      stop("Group column does not contain group2 value!")
    }

    set = ena.make.set(
      enadata = accum,
      rotation.by = ena.rotate.by.mean,
      rotation.params = list(accum$meta.data[[groupVar]] == group1, accum$meta.data[[groupVar]] == group2)
    )

    if(runTest == TRUE) {
      group1.rows = set$points[[groupVar]] == group1
      group2.rows = set$points[[groupVar]] == group2

      group1.dim1 = as.matrix(set$points)[group1.rows,1]
      group2.dim1 =  as.matrix(set$points)[group2.rows,1]

      group1.dim2 = as.matrix(set$points)[group1.rows,2]
      group2.dim2 = as.matrix(set$points)[group2.rows,2]

      if(testType == "nonparametric") {
        test.dim1 = wilcox.test(x = group1.dim1, y = group2.dim1)
        test.dim2 = wilcox.test(x = group1.dim2, y = group2.dim2)
      }
      else {
        test.dim1 = t.test(x = group1.dim1, y = group2.dim1)
        test.dim2 = t.test(x = group1.dim2, y = group2.dim2)
      }

      set$model$tests = list(test.dim1,test.dim2)
      return(set)
    }
    else {
      set$model$tests = NULL

      return(set)
    }
  }
}
