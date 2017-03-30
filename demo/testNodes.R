
testNodes = function(self) {

  optim = do_optimization_2(self, inPar = self$get("inPar") );

  positionsOptim = get_optimized_node_pos_c(self$data$normed, self$get("dimensions"), self$get("samples"), opted = self$data$optim);

  rotated = full_opt(normed = self$data$normed, rotated = self$data$centered$rotated, optim_nodes = self$nodes$positions$optim, dims = self$get("dimensions") );

  list(o = optim, pO = positionsOptim, r = rotated)
}
