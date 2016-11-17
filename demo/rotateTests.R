library(RcppArmadillo)
library(microbenchmark)

runENA_c <- function(accumulatedData, dims = 2, num_samples = 3, optimMethod = "C", inPar = F) {

  enaset = list();

  accumulatedData = accumulatedData;#accumulate.data(df, conversationsBy, unitsBy, codeNames, window=windowSize)

  enaset$dims = dims;
  enaset$samples = num_samples;

  enaset$data.normed = normIt(apply(as.matrix(accumulatedData)[,2:ncol(accumulatedData)], 2, as.numeric));

  enaset$data.centered = centerData(enaset$data.normed);
  enaset$data.centered.pca = pca(enaset$data.centered, dims = enaset$dims);
  enaset$data.centered.rotated = centerDataRotated(enaset$data.centered, enaset$data.centered.pca);

  enaset$rotation_dists = getRotationDistances(enaset$data.centered.rotated);

  #enaset$node.positions.optim_c = get_optimized_node_pos(enaset$data.normed, enaset$data.centereed.rotated, enaset$dims, enaset$samples);

  if(optimMethod == "C") {
    enaset$data.optim = do_optimization_2(enaset, inPar = inPar);
  } else {
    enaset$data.optim = do_optimization(enaset, inPar = inPar);
  }

  enaset$node.positions.optim = get_optimized_node_pos(enaset$data.normed, enaset$data.centered.rotated, enaset$dims, enaset$samples, opted = enaset$data.optim);
  #} else {
   #enaset$node.positions.optim = get_optimized_node_positions(enaset$data.normed, enaset$data.centered.rotated, num_dims = enaset$dims, num_samples = enaset$samples, data.optim = enaset$data.optim, return_all = T, optimMethod = optimMethod, inPar = inPar);
  #}

  enaset$node.positions.rotated = full_opt(normed = enaset$data.normed, rotated = enaset$data.centered.rotated, optim_nodes = enaset$node.positions.optim, dims = enaset$dims);

  return(enaset);
}

#print(microbenchmark(
  #set_c_Par = runENA_c(newRes, dims = 2, optimMethod = "C", inPar = T)
  #,

  #,
  #set_R = runENA_c(newRes, dims = 2, optimMethod = "R")
  #,times = 1000
  #))
