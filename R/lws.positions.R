##
#' @title LWS Positions
#' @description Position method developed by Jeff Linderoth in collaboration
#' with Epistemic Games
#'
#'
#' @export
##
lws.positions <- function(ena.set) {
  message("Running positions using the LWS method.");

  positions = linderoth_pos(ena.set$data$normed, ena.set$data$centered$rotated);

  ena.set$nodes$positions$scaled = positions$nodes;

  return(ena.set);
}
