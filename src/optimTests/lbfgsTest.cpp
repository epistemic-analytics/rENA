// [[Rcpp::depends(RcppArmadillo)]]
#include <RcppArmadillo.h>

using namespace arma;
using namespace Rcpp;
using namespace std;
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

// [[Rcpp::export]]
NumericMatrix c_cor(NumericMatrix mat) {
  return c_cor_helper(mat, 0, mat.nrow());
}

// [[Rcpp::export]]
double calc_cor(
    arma::vec x,
    List set,
    int dim
) {
  arma::mat dists = set["rotation_dists"];

  arma::mat t_pair_dists = dists.col(dim);
  arma::mat normed = set["data.normed"];

  uvec NtriOne = set["n1"];
  uvec NtriTwo = set["n2"];
  uvec KtriOne = set["k1"];
  uvec KtriTwo = set["k2"];

  arma::mat mps = trans(((x(NtriOne) + x(NtriTwo)) / 2));

  arma::mat multRes = normed * mps.t();
  arma::mat centroids = multRes / sum(normed, 1);
  arma::mat dcentroids = centroids(KtriOne) - centroids(KtriTwo);

  arma::mat cmat2(t_pair_dists.n_rows, 2);
  cmat2.col(0) = t_pair_dists;
  cmat2.col(1) = dcentroids;

  NumericMatrix cc = c_cor(Rcpp::wrap(cmat2));
  return cc(1,0);
  //return c(0,0);
}

// [[Rcpp::export]]
double calc_grad( arma::vec& x, List& set, int& dim) {
  int i;
  double eps, epsused, tmp, val1, val2;

  int n = set["N"];
  double fnscale = -1;

  NumericVector dpar, toRep, res, grad;
  dpar = NumericVector(n);
  grad = NumericVector(n);
  res = NumericVector(n);

  toRep = NumericVector::create(1);
  NumericVector parscale = rep_each(toRep, n);
  toRep = NumericVector::create(1);
  NumericVector ndeps = rep_each(toRep, n);
  toRep = NumericVector::create(-3);
  NumericVector lower = rep_each(toRep, n);
  toRep = NumericVector::create(3);
  NumericVector upper = rep_each(toRep, n);

  //     for (i = 0; i < n; i++) {
  //       res[i] = dpar[i] / parscale[i];
  //     }

  double s;
  for (i = 0; i < n; i++) {
    epsused = eps = ndeps[i];

    int l = lower[i] / parscale[i];
    int u = upper[i] / parscale[i];

    tmp = dpar[i] + eps;
    if (tmp > u) {
      tmp = u;
      epsused = tmp - dpar[i];
    }
    res[i] = tmp * parscale[i];
    s = calc_cor(res, set, dim);
    val1 = s / fnscale;


    tmp = dpar[i] - eps;
    if (tmp < l) {
      tmp = l;
      eps = dpar[i] - tmp;
    }
    res[i] = tmp * parscale[i];
    s = calc_cor(res, set, dim);
    val2 = s / fnscale;

    grad[i] = (val1 - val2)/(epsused + eps);

    res[i] = dpar[i] * parscale[i];
  }

  double cc = calc_cor(res, set, dim);
  return cc;
}

/*** R
control = list(invisible = 0, m = 6, epsilon = 1e-5, past = 0, delta = 0,
               max_iterations = 0, linesearch_algorithm = "LBFGS_LINESEARCH_DEFAULT",
               max_linesearch = 20, min_step = 1e-20, max_step = 1e+20, ftol = 1e-4,
               wolfe = 0.9, gtol = 0.9, orthantwise_c = 0, orthantwise_start = 0,
               orthantwise_end = e_list$N, xtol = .Machine$double.eps);
# objective <- function(x) {d
#   x1 <- x[1]
#   x2 <- x[2]
#   100 * (x2 - x1 * x1)^2 + (1 - x1)^2
# }
#
# gradient <- function(x) { ## Gradient of 'fr'
#   x1 <- x[1]
#   x2 <- x[2]
#   c(-400 * x1 * (x2 - x1 * x1) - 2 * (1 - x1),
#     200 *      (x2 - x1 * x1))
# }
output <- lbfgs(calc_cor, NULL, basePar, .GlobalEnv, ... = NULL)
# .Call('RlibLBFGS_lbfgs',
#       PACKAGE = 'lbfgs',
#       calc_cor, calc_grad, basePar,
#       .GlobalEnv, e_list$N,
#       control$invisible, control$m, control$epsilon,
#       control$past, control$delta, control$max_iterations,
#       control$linesearch, control$max_linesearch,
#       control$min_step, control$max_step, control$ftol,
#       control$wolfe, control$gtol, control$xtol,
#       control$orthantwise_c,  control$orthantwise_start,
#       control$orthantwise_end)
*/
