##
#' @title Accumulate Data
#'
#' @description This function will accumulate rows of data
#'
#' @details NEED TO ADD
#'
#' @export
#'
#' @param data.file The csv file location or data.frame for the function
#' @param conversation Columns used in the conversation
#' @param units Columns used based on units
#' @param codes Columns used based on codes
#' @param weight.by NEED DETAILS
#' @param trajectory.by NEED DETAILS
#' @param window.size Number of lines in the stanza
#' @param window.size.b Number of lines back to include window in stanza
#' @param windwo.size.f Number of lines forward to inclucde window in stanza
#'
#' @keywords data, accumulate
#'
#' @seealso \code{\link{ena.split.codes}}, \code{\link{ena.make.set}}
#'
#' @examples
#' #ADD EXAMPLES
#'
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
  if(output == "json") r6.to.json(data)
  else data
}
