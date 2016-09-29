library(RcppArmadillo)

normed = normIt(apply(as.matrix(newRes)[,2:7], 2, as.numeric));
rotatedC = rotate_c(normed)
centeredData = centerData(rotatedC);
centeredDataRotated = centerDataRotated(centeredData, rotatedC)
opt_nodes = full_opt(normed=normed, rotated=centeredDataRotated, 3) #, )$x_scaled[, dimensions];
