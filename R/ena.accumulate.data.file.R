##
#' @title Accumulate Data from csv
#'
#' @description This function accumulates rows of data.
#'
#' @details [TBD]
#'
#' @export
#'
#' @param file The csv file location or data.frame for the function
#' @param units.used Delimits columns based on the units (which specific units to use)
#' @param units.by unit columns to accumulate by
#' @param conversations.by Columns used in the conversation
#' @param codes Columns used based on codes
#' @param window.size Number of lines in the stanza
#' @param window.size.back Number of lines back to include window in stanza
#' @param window.size.forward Number of lines forward in stanza window
#' @param binary [TBD]
#' @param correction [TBD]
#' @param units.exclude Exclude certain columns based on units
#' @param trajectory.by [TBD]
#' @param trajectory.type [TBD]
#' @param output ENAdata object or JSON string. Default: ENAdata
#' @param output.fields Fields to be included in JSON output
#' @param ... additional parameters addressed in inner function
#'
#' @keywords data, accumulate
#'
#' @seealso \code{\link{ena.split.codes}}, \code{\link{ena.make.set}}
#'
#' @examples
#' \dontrun{
#' codeNames = c(
#'   "E.data","S.data","E.design","S.design","S.professional","E.client",
#'   "V.client","E.consultant","V.consultant","S.collaboration","I.engineer",
#'   "I.intern","K.actuator","K.rom","K.materials","K.power"
#' )
#'
#' df.file <- system.file("extdata", "rs.data.csv", package="rENA")
#'
#' # Given a csv file location
#' ena.accumulate.data(
#'   df.file, units.by = c("UserName","Condition"),
#'   conversations.by = c("ActivityNumber","GroupName"),
#'   codes = codeNames
#' )
#' }
#' @return \code{\link{ENAdata}} class object with accumulated data
#'
##
ena.accumulate.data.file <- function(
  file,

  units.used = NULL,   #subset of actual unit values to use for accumulation - all used if not specified

  units.by,    #unit columns to merge on to create ENA_UNIT --- MUST BE SUPPLIED
  conversations.by,    #conversation columns to accumulate by --- MUST BE SUPPLIED

  codes = NULL,

  #window.size = 1,
  window.size.back = 1,
  window.size.forward = NULL,

  weight.by = "binary",

  units.exclude = c(),

  model = c("EndPoint", "AccumulatedTrajectory", "SeparateTrajectory"),   #use match arg and list?
  #trajectory.by = NULL,     #no longer used, trajectories are always by activity
  #trajectory.type = c("accumulated","non-accumulated"),     #into model

  mask = NULL,

  output = c("class","json"),    #keep for now
  output.fields = NULL,       #keep for now
  ...
) {
  #print(file);
  if(is.null(file) || is.null(units.by) || is.null(conversations.by) || is.null(codes)) {
    print("ACCUMULATION FROM FILE REQUIRES: file, units.by, conversations.by, and codes");
  }

  units = NULL;    #will be populated once csv is read

  model = match.arg(model)

  data = ENAdata$new(
    file,

    units,
    units.used,

    units.by,
    conversations.by,

    codes,

    window.size,
    window.size.back,
    window.size.forward,

    weight.by,

    units.exclude,

    model = model,
    mask,

    ...
  );

  data$function.call = sys.call();
  output = match.arg(output);
  if(output == "json") {
    output.class = get(class(data))

    if(is.null(output.fields)) {
      output.fields = names(output.class$public_fields)
    }

    r6.to.json(data, o.class = output.class, o.fields = output.fields)
  }
  else data
}
