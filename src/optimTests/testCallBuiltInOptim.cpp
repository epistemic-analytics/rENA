// [[Rcpp::depends(RcppArmadillo)]]
#include <RcppArmadillo.h>

using namespace arma;
using namespace Rcpp;

typedef vec (*funcPtr)(const vec& x);
typedef SEXP (*funcPtr2)(SEXP call, SEXP op, SEXP args, SEXP rho);


XPtr<funcPtr2> putFunPtrInXPtr(SEXP fn) {
  Rcpp::Rcout << "Fun: " << TYPEOF(fn) << " == " << EXTPTRSXP << std::endl;
  XPtr<funcPtr2> newFn(fn);
  return newFn;
}



void callViaXPtr(SEXP call, SEXP op, SEXP args, SEXP rho) {
  XPtr<funcPtr2> xpfun(call);
  funcPtr2 fun = *xpfun;

  SEXP res = fun(call, op, args, rho);
  Rcpp::Rcout << "Res: " << res << std::endl;
  // vec y;
  // return (y);
}


/*** R
getwd();
load('../rENA.RData')
Rcpp::sourceCpp('ena.cpp');
maxit = 1000
e = enaset;
e_ = e;

e = e_ = enaset;
e_list = list(
  data.normed = e$line.weights.non.zero,
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
args <- list( par = basePar, fn = calc_cor, gr = NULL, method = "Nelder-Mead", options = con, slower=-3, supper=3 );
#source("../demo/new_optim_test.R")
# fun <- putFunPtrInXPtr("fun2")

fnPtr = putFunPtrInXPtr(stats:::C_optim$address)
#callViaXPtr(fnPtr, list(), args, .GlobalEnv)
#Rcpp::sourceCpp('src/statsHeaderTest.cpp'); callViaXPtr(fnPtr, list(), args, .GlobalEnv)

*/
