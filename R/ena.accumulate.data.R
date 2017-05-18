##
#' @title Accumulate Data
#' @description Accumulate rows of data
#'
#'
#'
#' @export
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
