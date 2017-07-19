##
# @title LWS Positions
# @description Position method developed by Jeff Linderoth in collaboration
# with Epistemic Games
#
#
# @export
##
lws.positions <- function(enaset) {
  message("Running positions using the LWS method.");

  positions = linderoth_pos(enaset$line.weights.non.zero, enaset$points.rotated);

  enaset$node.positions = positions$nodes;
  rownames(enaset$node.positions) = enaset$enaData$codes;
  return(enaset);
}

# Ellipsoidal scaling versino
lws.positions.es <- function(enaset) {
  message("Running positions using the LWS method and ellipsoidal scaling.");

  positions = linderoth_pos_es(enaset$line.weights.non.zero, enaset$points.rotated);

  enaset$node.positions = positions$nodes;
  rownames(enaset$node.positions) = enaset$enaData$codes;
  return(enaset);
}

