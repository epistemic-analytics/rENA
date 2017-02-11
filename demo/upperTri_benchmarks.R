library("microbenchmark");
#library("rENA");
library("Rcpp");
useVec = round(runif(200, 0, 4))
nTimes = 1000

cppFunction("arma::mat v(arma::colvec a) { return a*a.t();}", depends="RcppArmadillo")

tryCatch(
  expr = (bench = microbenchmark( times=nTimes,
      old.upper(useVec),
      vector_to_ut(useVec),
      v(useVec)
      #vec_tri_full(useVec)
    ))
  ,finally = {
    if(exists("bench")) {
      print(bench);
      rm(bench);
    }
    if(exists("nTimes")) rm(nTimes);
    if(exists("useVec")) rm(useVec);
  }
)
