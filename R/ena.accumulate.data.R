##
#' @title Accumulate data from a data frame into a set of adjacency (co-occurrence) vectors
#'
#' @description This function initializes an ENAdata object, processing conversations from coded data to generate adjacency (co-occurrence) vectors
#'
#' @details ENAData objects are created using this function. This accumulation receives
#' separate data frames for units, codes, conversation, and optionally, metadata. It
#' iterates through the data to create an adjacency (co-occurrence) vector corresponding
#' to each unit - or in a trajectory model multiple adjacency (co-occurrence) vectors for
#' each unit.
#'
#' In the default MovingStanzaWindow model, co-occurrences between codes are
#' calculated for each line k in the data between line k and the window.size.back-1 previous
#' lines and window.size.forward-1 subsequent lines in the same conversation as line k.
#'
#' In the Conversation model, co-occurrences between codes are calculated across all lines in
#' each conversation. Adjacency (co-occurrence) vectors are constructed for each unit u by
#' summing the co-occurrences for the lines that correspond to u.
#'
#' Options for how the data is accumulated are endpoint, which produces one adjacency (co-occurrence)
#' vector for each until summing the co-occurrences for all lines, and two trajectory models:
#' AccumulatedTrajectory and SeparateTrajectory. Trajectory models produce an adjacency
#' (co-occurrence) model for each conversation for each unit. In a SeparateTrajectory model,
#' each conversation is modeled as a separate network. In an AccumulatedTrajectory model, the
#' adjacency (co-occurrence) vector for the current conversation includes the co-occurrences
#' from all previous conversations in the data.
#'
#' @export
#'
#' @param units A data frame where the columns are the properties by which units will be identified
#' @param conversation A data frame where the columns are the properties by which conversations will be identified
#' @param codes A data frame where the columns are the codes used to create adjacency (co-occurrence) vectors
#' @param metadata (optional) A data frame with additional columns of metadata to be associated with each unit in the data
#' @param model A character, choices: EndPoint (or E), AccumulatedTrajectory (or A), or SeparateTrajectory (or S); default: EndPoint. Determines the ENA model to be constructed
#' @param weight.by (optional) A function to apply to values after accumulation
#' @param mask (optional) A binary matrix of size ncol(codes) x ncol(codes). 0s in the mask matrix row i column j indicates that co-occurrence will not be modeled between code i and code j
#' @param window A character, choices are Conversation (or C), MovingStanzaWindow (MSW, MS); default MovingStanzaWindow. Determines how stanzas are constructed, which defines how co-occurrences are modeled
#' @param window.size.back A positive integer, Inf, or character (INF or Infinite), default: 1. Determines, for each line in the data frame, the number of previous lines in a conversation to include in the stanza window, which defines how co-occurrences are modeled
#' @param window.size.forward (optional) A positive integer, Inf, or character (INF or Infinite), default: 0. Determines, for each line in the data frame, the number of subsequent lines in a conversation to include in the stanza window, which defines how co-occurrences are modeled
#' @param ... additional parameters addressed in inner function
#' @param include.meta Locigal indicating if unit metadata should be attached to the resulting ENAdata object, default is TRUE
#' @param as.list R6 objects will be deprecated, but if this is TRUE, the original R6 object will be returned, otherwise a list with class `ena.set`
#'
#' @seealso \code{\link{ENAdata}}, \code{\link{ena.make.set}}
#'
#' @return \code{\link{ENAdata}} object with data [adjacency (co-occurrence) vectors] accumulated from the provided data frames.
#'
##
ena.accumulate.data <- function(
  units = NULL,
  conversation = NULL,
  codes = NULL,
  metadata = NULL,
  model = c("EndPoint", "AccumulatedTrajectory", "SeparateTrajectory"),
  weight.by = "binary",
  window = c("MovingStanzaWindow", "Conversation"),
  window.size.back = 1,
  window.size.forward = 0,
  mask = NULL,
  include.meta = T,
  as.list = T,
  ...
) {
  if (is.null(units) || is.null(conversation) || is.null(codes)) {
    stop("Accumulation requires: units, conversation, and codes");
  }
  if (nrow(units) != nrow(conversation) || nrow(conversation) != nrow(codes)) {
    stop("Data Frames do not have the same number of rows");
  }
  check_code_values(codes)

  df <- cbind(units, conversation);
  df <- cbind(df, codes);

  # A metadata table whose rows don't line up with the data used to be dropped
  # without a word.
  if (!is.null(metadata) && NROW(metadata) > 0) {
    if (NROW(metadata) != nrow(df))
      stop("metadata has ", NROW(metadata), " rows but the data has ", nrow(df))
  }
  metadata <- data.table::as.data.table(metadata)
  if (nrow(metadata) == nrow(df)) {
    df <- cbind(df, metadata);
  }

  model <- match.arg(model)
  window <- match.arg(window)

  units.by <- colnames(units);
  conversations.by <- colnames(conversation);
  if (identical(window, "Conversation")) {
    conversations.by <- c(conversations.by, units.by);
    window.size.back <- window;
  }
  else if (identical(window, "MovingStanzaWindow")) {
    if( grepl(pattern = "inf", x = window.size.back, ignore.case = T)) {
      window.size.back <- Inf
    }
    if( grepl(pattern = "inf", x = window.size.forward, ignore.case = T)) {
      window.size.forward <- Inf
    }
  }

  data <- ENAdata$new(
    file = df,
    units = units,
    units.by = units.by,
    conversations.by = conversations.by,
    codes = codes,
    window.size.back = window.size.back,
    window.size.forward = window.size.forward,
    weight.by = weight.by,
    model = model,
    mask = mask,
    include.meta = include.meta,
    ...
  );
  data$process()

  data$function.call <- sys.call()

  if(as.list) {
    data <- ena.set(data)
  } else {
    warning(paste0("Usage of R6 data objects is deprecated and may be removed ",
      "entirely in a future version. Consider upgrading to the new data ",
      "object."))
  }

  data
}

# Code columns must be complete and numeric (or logical). An NA in a code made
# the unit's whole connection count NA, which then became an all-zero network
# at the origin -- dropping the unit's valid connections without a warning.
check_code_values <- function(codes) {
  codes <- as.data.frame(codes)
  bad_type <- names(codes)[!vapply(codes, function(x) is.numeric(x) || is.logical(x), logical(1))]
  if (length(bad_type))
    stop("Code columns must be numeric or logical: ", paste(bad_type, collapse = ", "))
  has_na <- names(codes)[vapply(codes, anyNA, logical(1))]
  if (length(has_na))
    stop("Code columns contain missing values (NA): ", paste(has_na, collapse = ", "),
         ". Recode them (e.g. to 0) before accumulating.")
  invisible(TRUE)
}
