##
# @title EGR Positions
# @description Original ENA position method developed by Epistemic Games
#
#
# @export
##
egr.positions <- function(ena.set) {
  ###
  # Calculate the rotation distances
  ###
    ena.set$rotation_dists = getRotationDistances_c(ena.set$data$centered$rotated.non.zero);

  ###

  ###
  # Perform the optimization
  ###
    ena.set$data$optim = ena.set$optim.method(ena.set, inPar = ena.set$get("inPar"));
  ###

  ###
  # Store the optimized node positions
  ###
    ena.set$nodes$positions$optim = get_optimized_node_pos_c(
      ena.set$data$normed.non.zero, ena.set$get("dimensions"), ena.set$get("samples"), opted = ena.set$data$optim
    );
  ###

  ###
  # Store the unscaled node positions
  ###
    ena.set$nodes$positions$unscaled = full_opt_c(
      normed = ena.set$data$normed.non.zero,
      rotated = ena.set$data$centered$rotated.non.zero,
      optim_nodes = ena.set$nodes$positions$optim,
      dims = ena.set$get("dimensions"), num_samples = ena.set$get("samples")
      ,checkUnique = ena.set$check.unique.positions
    );
    rownames(ena.set$nodes$positions$unscaled$positions) = ena.set$get("enaData")$get("code.names");
  ###

  ###
  # Scale the node positions
  ###
    ena.set$nodes$positions$scaled = full_opt_soln(
      ena.set$nodes$positions$unscaled$positions,
      ena.set$data$normed.non.zero,
      ena.set$data$centered$rotated.non.zero
    )$positions;
    rownames(ena.set$nodes$positions$scaled) = ena.set$get("enaData")$get("code.names");
  ###

  return(ena.set);
}
