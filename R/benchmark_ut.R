#' Run benchmarks on the Upper Triangle creation functions
#'
#' @param v Vector to create the upper triangle from
#' @param times Number of times to run the benchmark
#'
#' @return microbenchmark results
#' @export
benchmark_ut <- function(v = 1:4, times = 100) {
  tryCatch(
    expr = (bench = microbenchmark::microbenchmark( times=times,
                old.upper(v),
                vector_to_ut(v),
                vector_to_ut_full(v)
              )
    )
    ,finally = {
      if(exists("bench")) return(bench)
      else return(NULL)
    }
  )
}
