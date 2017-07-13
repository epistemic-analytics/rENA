##
# @title LWS Positions
# @description Position method developed by Jeff Linderoth in collaboration
# with Epistemic Games
#
#
# @export
##
lws.positions <- function(ena.set) {
  message("Running positions using the LWS method.");

  positions = linderoth_pos(ena.set$data$normed, ena.set$data$centered$rotated);

  ena.set$nodes$positions$scaled = positions$nodes;

  rownames(ena.set$nodes$positions$scaled) = ena.set$get("enaData")$get("code.names");
  return(ena.set);
}

# Ellipsoidal scaling versino
lws.positions.es <- function(ena.set) {
  message("Running positions using the LWS method and ellipsoidal scaling.");

  positions = linderoth_pos_es(ena.set$data$normed, ena.set$data$centered$rotated);

  ena.set$nodes$positions$scaled = positions$nodes;
  ena.set$nodes$positions$optim$Correlations = positions$correlations;
  ena.set$nodes$positions$optim$centroids = positions$centroids;
  ena.set$nodes$positions$optim$points = positions$points;
  ena.set$nodes$weights = positions$weights;

  rownames(ena.set$nodes$positions$scaled) = ena.set$get("enaData")$get("code.names");
  return(ena.set);
}

