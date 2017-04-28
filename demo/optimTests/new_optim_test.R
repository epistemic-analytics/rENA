#source('demo/forCody.R');
#source("./demo/new_optim_test.R")
load('rENA.RData');

maxit = 1000
e = enaset;
e_ = e;

e = e_ = enaset;
e_list = list(
  data.normed = e$data$normed.non.zero,
  rotation_dists = e$rotation_dists,
  dims = e$get("dimensions"),
  samples = e$get("samples"),
  N = e_$get('N'),
  K = e_$get('K'),

  ###
  # These indices have been increased from the initial C++
  # calculations for use as R indices. Decrease all of them
  # for safe use in C++ again.
  ###
  n1 = e_$get('n1') - 1,
  n2 = e_$get('n2') - 1,
  k1 = e_$get('k1') - 1,
  k2 = e_$get('k2') - 1
);
basePar = runif(e_list$N,-3,3);

con <- list(trace = 0, fnscale = -1, parscale = rep.int(1, e_list$N),
            ndeps = rep.int(1e-3, e_list$N),
            maxit = 500, abstol = -Inf, reltol = sqrt(.Machine$double.eps),
            alpha = 1.0, beta = 0.5, gamma = 2.0,
            REPORT = 10,
            type = 1, lmm = 5, factr = 1e7, pgtol = 0,
            tmax = 10, temp = 10.0, lower=-3, upper=3);

Rcpp::sourceCpp('src/ena.cpp');
# Rcpp::sourceCpp('src/optim_c.cpp');
#
# options(error=traceback)
# #options(show.error.locations = TRUE)
# #options(error = quote({dump.frames(to.file=TRUE); q()}))
# tryCatch({
#
#   gr1 <- function(par) { calc_grad(par,...) };
#   fn1 <- function(par) { calc_cor(par, e_list, 1) };
#
#   #res=optim_nm_cor(basePar, list(), list(method="Nelder-Mead",args=list(set=e_list,dim=1)), list(), -3,3);
#
#   # microbenchmark::microbenchmark(
    # suppressWarnings(optim(par = basePar,
    #                      fn = calc_cor,
    #                      gr = NULL,
    #                      e_list, 1, # ... parameters to calc_cor()
    #                      method = "Nelder-Mead",
    #                      control = list(fnscale=-1, parscale=rep(.1,e_list$N), maxit=5000), lower=-3, upper=3))
#     # "direct" = .External2(stats:::C_optim, basePar, fn1, gr1, "L-BFGS-B", con, rep_len(-3,e_list$N), rep_len(3,e_list$N)),
#     # times=1000
#   # )
# }, error = function(e) {
#   print("Error."); print(e);
# })
