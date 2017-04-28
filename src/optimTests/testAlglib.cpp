#include <RcppArmadillo.h>
using namespace Rcpp;

#include "alglib/stdafx.h"
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include "alglib/optimization.h"

using namespace std;
using namespace alglib;

struct asset_info {
  double sum, sum2, stdev;
};

//[correlation matrix](http://en.wikipedia.org/wiki/Correlation_and_dependence).
// n,sX,sY,sXY,sX2,sY2
// cor = ( n * sXY - sX * sY ) / ( sqrt(n * sX2 - sX^2) * sqrt(n * sY2 - sY^2) )
inline asset_info compute_asset_info(const NumericMatrix& mat,
                                     const int icol, const int rstart, const int rend) {
  double sum, sum2;
  sum = sum2 = 0;

  for (int r = rstart; r < rend; r++) {
    double d = mat(r, icol);
    sum += d;
    sum2 += pow(d,2);
  }

  asset_info res;
  res.sum = sum;
  res.sum2 = sum2;
  res.stdev = sqrt( (double) ((rend-rstart) * sum2 - pow(sum, 2)) );
  return res;
}

inline NumericMatrix c_cor_helper(const NumericMatrix& mat, const int rstart, const int rend) {
  int nc = mat.ncol();
  int nperiod = rend - rstart;
  NumericMatrix rmat(nc, nc);

  vector<asset_info> info(nc);
  for (int c = 0; c < nc; c++)
    info[c] = compute_asset_info(mat, c, rstart, rend);

  for (int c1 = 0; c1 < nc; c1++) {
    for (int c2 = 0; c2 < c1; c2++) {
      double sXY = 0;

      for (int r = rstart; r < rend; r++)
        sXY += mat(r, c1) * mat(r, c2);

      rmat(c1, c2) = (nperiod * sXY - info[c1].sum * info[c2].sum) / (info[c1].stdev * info[c2].stdev);
    }
  }

  return rmat;
}
NumericMatrix c_cor(NumericMatrix mat) {
  return c_cor_helper(mat, 0, mat.nrow());
}
void calc_cor(
    const real_1d_array &x_,
    double &func, void *ptr
    // List set,
    // int dim
) {
  arma::vec x(x_.length());
  for(int i = 0; i < x_.length(); i++) {
    x[i] = x_[i];
  }

  List set = List::create();
  int dim = 0;
  arma::mat dists = set["rotation_dists"];

  arma::mat t_pair_dists = dists.col(dim);
  arma::mat normed = set["data.normed"];

  arma::uvec NtriOne = set["n1"];
  arma::uvec NtriTwo = set["n2"];
  arma::uvec KtriOne = set["k1"];
  arma::uvec KtriTwo = set["k2"];

  arma::mat mps = trans(((x(NtriOne) + x(NtriTwo)) / 2));

  arma::mat multRes = normed * mps.t();
  arma::mat centroids = multRes / sum(normed, 1);
  arma::mat dcentroids = centroids(KtriOne) - centroids(KtriTwo);

  arma::mat cmat2(t_pair_dists.n_rows, 2);
  cmat2.col(0) = t_pair_dists;
  cmat2.col(1) = dcentroids;

  NumericMatrix cc = c_cor(Rcpp::wrap(cmat2));
  func = cc(1,0);
}


// [[Rcpp::export]]
int timesTwo(int toTimes) {
  //
  // This example demonstrates minimization of f(x,y) = 100*(x+3)^4+(y-3)^4
  // using numerical differentiation to calculate gradient.
  //
  real_1d_array x = "[0,0]";
  double epsg = 0.0000000001;
  double epsf = 0;
  double epsx = 0;
  double diffstep = 1.0e-6;
  ae_int_t maxits = 0;
  minlbfgsstate state;
  minlbfgsreport rep;

  minlbfgscreatef(1, x, diffstep, state);
  minlbfgssetcond(state, epsg, epsf, epsx, maxits);
  alglib::minlbfgsoptimize(state, calc_cor);
  minlbfgsresults(state, x, rep);

  return 0;
}
