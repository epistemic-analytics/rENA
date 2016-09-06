library("microbenchmark");
library("rENA");

useVec = round(runif(200, 0, 4))
nTimes = 1000

tryCatch(
  expr = (bench = microbenchmark( times=nTimes,
      old.upper(useVec),
      vector_to_ut(useVec)
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
