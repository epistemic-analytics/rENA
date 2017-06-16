##
#' @title Accumulate Data
#'
#' @description This function accumulates rows of data.
#'
#' @details [TBD]
#'
#' @export
#'
#' @param file The csv file location or data.frame for the function
#' @param units.by Delimits columns based on the units
#' @param units Columns used based on units
#' @param conversations.by Columns used in the conversation
#' @param code.names Columns used based on codes
#' @param window.size Number of lines in the stanza
#' @param window.size.back Number of lines back to include window in stanza
#' @param window.size.forward Number of lines forward in stanza window
#' @param binary [TBD]
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
#'   code.names = codeNames
#' )
#' }
#' @return \code{\link{ENAdata}} class object with accumulated data
#'
##
ena.accumulate.data <- function(
  file,
  units.by = NULL,
  units = NULL,
  conversations.by = NULL,
  code.names = NULL,
  window.size = 1,
  window.size.back = window.size,
  window.size.forward = NULL,
  binary = T,
  units.exclude = c(),
  trajectory.by = NULL,
  trajectory.type = c("accumulated","non-accumulated"),
  output = c("class","json"),
  output.fields = NULL,
  ...
) {
  data = ENAdata$new(
    file,
    units.by,
    units,
    conversations.by,
    code.names,
    window.size,
    window.size.back,
    window.size.forward,
    binary,
    units.exclude,
    trajectory.by = trajectory.by,
    trajectory.type = match.arg(trajectory.type),
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
