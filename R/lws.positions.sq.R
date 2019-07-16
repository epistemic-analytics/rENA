##
# @title LWS Least-Square Positions
# @description Least-Squares Position method developed by Jeff Linderoth in collaboration
# with Epistemic Games
#
#
# @export
##
# lws.positions <- function(enaset) {
#   # message("Running positions using the LWS method.");
#
#   positions = linderoth_pos(enaset$line.weights.non.zero, enaset$points.rotated);
#
#   enaset$node.positions = positions$nodes;
#   rownames(enaset$node.positions) = enaset$enadata$codes;
#   return(enaset);
# }

# Ellipsoidal scaling version
lws.positions.sq <- function(enaset) {
  points = enaset$points[,!colnames(enaset$points) %in% colnames(enaset$meta.data), with=F]
  positions = lws_lsq_positions(as.matrix(enaset$line.weights), as.matrix(points), ncol(points));

  node.positions = positions$nodes;
  rownames(node.positions) = enaset$enadata$codes;

  return(list("node.positions" = node.positions, "centroids" = positions$centroids))
}
