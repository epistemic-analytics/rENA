library(RcppArmadillo)
library(microbenchmark)

runENA_c <- function(accumulatedData, dims = 2, num_samples = 3) {

  enaset = list();

  accumulatedData = accumulate.data(df, conversationsBy, unitsBy, codeNames, window=windowSize)

  enaset$dims = dims;
  enaset$samples = num_samples;

  enaset$data.normed = normIt(apply(as.matrix(accumulatedData)[,2:ncol(accumulatedData)], 2, as.numeric));

  enaset$data.centered = centerData(enaset$data.normed);
  enaset$data.centered.pca = pca(enaset$data.centered, dims = enaset$dims);
  enaset$data.centered.rotated = centerDataRotated(enaset$data.centered, enaset$data.centered.pca);

  enaset$rotation_dists = getRotationDistances(enaset$data.centered.rotated);


  #enaset$node.positions.optim_c = get_optimized_node_pos(enaset$data.normed, enaset$data.centereed.rotated, enaset$dims, enaset$samples);
  enaset$node.positions.optim = get_optimized_node_pos(enaset$data.normed, enaset$data.centered.rotated, enaset$dims, enaset$samples);

  enaset$node.positions.rotated = full_opt(normed = enaset$data.normed, rotated = enaset$data.centered.rotated, optim_nodes = enaset$node.positions.optim, dims = enaset$dims);

  return(enaset);
}

#print(microbenchmark(
set = runENA_c(newRes, dims = 4)
#, times = 1000))
