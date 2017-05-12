#' Run benchmarks on the Upper Triangle creation functions
#'
#' @param v Vector to create the upper triangle from
#' @param times Number of times to run the benchmark
#'
#' @return microbenchmark results
#' @export


Rcpp::sourceCpp('src/vector_to_ut.cpp');
Rcpp::sourceCpp('src/vector_to_ut_full.cpp');
source('R/old.upper.R');
benchmark_ut <- function(v = 1:4, times = 100) {
  tryCatch(
    expr = (bench = microbenchmark::microbenchmark( times=times,
                R.upper.tri(v),
                R.upper.tri.2(v),
                vector_to_ut_mul(v),
                vector_to_ut(v)
              )
    )
    ,finally = {
      if(exists("bench")) return(bench)
      else return(NULL)
    }
  )
}

print(benchmark_ut(1:32,100))
