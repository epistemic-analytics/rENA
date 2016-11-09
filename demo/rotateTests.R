library(RcppArmadillo)
library(microbenchmark)

runENA_c <- function(accumulatedData, dims = 2) {

  enaset = list();

  newRes = accumulate(df, conversationsBy, unitsBy, codeNames, window=windowSize)

  enaset$dims = dims;

  enaset$data.normed = normIt(apply(as.matrix(accumulatedData)[,2:ncol(accumulatedData)], 2, as.numeric));
  enaset$data.centered = centerData(enaset$data.normed);
  enaset$data.centered.pca = pca(enaset$data.centered, dims = enaset$dims);
  enaset$data.centered.rotated = centerDataRotated(enaset$data.centered, enaset$data.centered.pca);

  enaset$node.positions.rotated = full_opt(normed = enaset$data.normed, rotated = enaset$data.centered.rotated, dims = enaset$dims);

  return(enaset);
}

print(microbenchmark(
#set =
  runENA_c(newRes, dims = 4)
, times = 1000))
