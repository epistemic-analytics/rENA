/*
 *  R : A Computer Language for Statistical Data Analysis
 *  Copyright (C) 1999-2013  The R Core Team
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, a copy is available at
 *  https://www.R-project.org/Licenses/
 */

#include <math.h>
#include <RcppArmadillo.h>

using namespace Rcpp;
using namespace arma;
using namespace std;

#define big 1.0e+35   /*a very large number*/

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
void calc_grad(
    const int& n,
    const List& set,
    const int& dim,
    const double& fnscale,
    const NumericVector& p,
    NumericVector& df,
    const NumericVector& parscale,
    const NumericVector& ndeps,
    const NumericVector& upper,
    const NumericVector& lower
) {
  int i;
  double val1, val2, eps, epsused, tmp;
  //OptStruct OS = (OptStruct) ex;

  NumericVector x(n);
  double s;
  for (i = 0; i < n; i++) {
    epsused = eps = ndeps[i];
    tmp = p[i] + eps;
    if (tmp > upper[i]) {
      tmp = upper[i];

      epsused = tmp - p[i];
    }
    x[i] = tmp * parscale[i];
    s = calc_cor(x, set, dim);

    val1 = s / fnscale;
    tmp = p[i] - eps;
    if (tmp < lower[i]) {
      tmp = lower[i];
      eps = p[i] - tmp;
    }
    x[i] = tmp * parscale[i];
    s = calc_cor(x, set, dim);

    val2 = s / fnscale;
    df[i] = (val1 - val2)/(epsused + eps);

    if(!is_finite(df[i]))
      std::range_error("non-finite finite-difference value.");

    x[i] = p[i] * parscale[i];
  }
}

double fminfn(
  int n,
  NumericVector p, NumericVector OS_parscale,
  double OS_fnscale,
  List set,
  int dim
) {
  NumericVector s(n);
  NumericVector x(n);
  int i;
  double val = 2.0;

  for (i = 0; i < n; i++) {
    x[i] = p[i] * OS_parscale[i];
  }

  //Rcpp::Rcout << "X: " << x << std::endl;
  double sCor = calc_cor(Rcpp::as<arma::vec>(x), set, dim);

  // if (s.size() != 1)
  //  std::range_error("objective function in optim evaluates to length that's not 1");
  val = sCor / OS_fnscale;

  return val;
}

/* Nelder-Mead, based on Pascal code
 in J.C. Nash, `Compact Numerical Methods for Computers', 2nd edition,
converted by p2c then re-crafted by B.D. Ripley */
List nmmin_c(int n, NumericVector Bvec, NumericVector X, double Fmin,
           double abstol, double intol,
           NumericVector OS_parscale, double OS_fnscale,
           double alpha, double bet, double gamm, int trace,
           int fncount, int maxit,
           List set, int dim)
{
  int C;
  int fail = 0;
  bool calcvert;
  double convtol, f;
  int funcount=0, H, i, j, L=0;
  int n1=0;
  double oldsize;
  double size, step, temp, trystep;
  double VH, VL, VR;

  NumericMatrix P(n, n+1);

  if (maxit <= 0) {
    Fmin = fminfn(n, Bvec, OS_parscale, OS_fnscale, set, dim);
    fncount = 0;
    fail = 0;

    return Rcpp::List::create(
      _("value") = Fmin,
      _("ifail") = fail,
      _("fncount") = fncount,
      _("opar") = X
    );
  }

  fail = false;
  Rcpp::Rcout << "n: " << n << std::endl;
  Rcpp::Rcout << "Bvec: " << Bvec << std::endl;
  Rcpp::Rcout << "OS_parscale: " << OS_parscale << std::endl;
  Rcpp::Rcout << "OS_fnscale: " << OS_fnscale << std::endl;
  Rcpp::Rcout << "dim: " << dim << std::endl;

  f = fminfn(n, Bvec, OS_parscale, OS_fnscale, set, dim);
  if (!is_finite(f)) {
    Rcpp::Rcout << "Failed now." << f << std::endl;
    Rcpp::exception("function cannot be evaluated at initial parameters");

    fail = true;
  } else {
    Rcpp::Rcout << "Here now." << std::endl;

    funcount = 1;
    convtol = intol * (abs(f) + intol);

    n1 = n + 1;
    C = n + 2;
    P(n1-1,0) = f;
    for (i = 0; i < n; i++)
      P(i,0) = Bvec[i];


    Rcpp::Rcout << "P: " << P << std::endl;

    L = 1;
    size = 0.0;
    step = 0.0;

    for (i = 0; i < n; i++) {
      if (0.1 * abs(Bvec[i]) > step)
        step = 0.1 * abs(Bvec[i]);
    }

    if (step == 0.0) step = 0.1;
    for (j = 2; j <= n1; j++) {
      for (i = 0; i < n; i++)
        P(i,j - 1) = Bvec[i];

      trystep = step;
      while (P(j - 2,j - 1) == Bvec[j - 2]) {
        P(j - 2,j - 1) = Bvec[j - 2] + trystep;
        Rcpp::Rcout << "ts1: " << trystep << std::endl;
        trystep *= 10;
        Rcpp::Rcout << "ts2: " << trystep << std::endl;
      }
      size += trystep;
    }
    oldsize = size;
    calcvert = true;
    do {
      if (calcvert) {
        for (j = 0; j < n1; j++) {
          if (j + 1 != L) {
            for (i = 0; i < n; i++)
              Bvec[i] = P(i,j);

            f = fminfn(n, Bvec, OS_parscale, OS_fnscale, set, dim);

            if (!is_finite(f)) f = big;
            funcount = funcount + 1;
            P(n1 - 1,j) = f;
          }
        }
        calcvert = false;
      }

      VL = P(n1 - 1,L - 1);
      VH = VL;
      H = L;

      for (j = 1; j <= n1; j++) {
        if (j != L) {
          f = P(n1 - 1,j - 1);
          if (f < VL) {
            L = j;
            VL = f;
          }
          if (f > VH) {
            H = j;
            VH = f;
          }
        }
      }

      if (VH <= VL + convtol || VL <= abstol) {
        Rcpp::Rcout << "VH: " << VR << std::endl;
        Rcpp::Rcout << "VL: " << VL << std::endl;
        break;
      }


      for (i = 0; i < n; i++) {
        temp = -P(i,H - 1);
        for (j = 0; j < n1; j++)
          temp += P(i,j);
        P(i,C - 1) = temp / n;
      }
      for (i = 0; i < n; i++) {
        Bvec[i] = ((1.0 + alpha) * P(i,C - 1)) - (alpha * P(i,H - 1));
      }

      f = fminfn(n, Bvec, OS_parscale, OS_fnscale, set, dim);

      if (!is_finite(f)) f = big;

      funcount = funcount + 1;

      VR = f;
      if (VR < VL) {
        P(n1 - 1,C - 1) = f;

        for (i = 0; i < n; i++) {
          f = (gamm * Bvec[i]) + ((1 - gamm) * P(i,C - 1));
          P(i,C - 1) = Bvec[i];
          Bvec[i] = f;
        }

        f = fminfn(n, Bvec, OS_parscale, OS_fnscale, set, dim);
        if (!is_finite(f)) f = big;

        funcount = funcount + 1;
        if (f < VR) {
          for (i = 0; i < n; i++)
            P(i,H - 1) = Bvec[i];

          P(n1 - 1,H - 1) = f;
          //strcpy(action, "EXTENSION      ");
        } else {
          for (i = 0; i < n; i++)
            P(i,H - 1) = P(i,C - 1);

          P(n1 - 1,H - 1) = VR;
        }
      } else {
        //strcpy(action, "HI-REDUCTION   ");
        if (VR < VH) {
          for (i = 0; i < n; i++)
            P(i,H - 1) = Bvec[i];

          P(n1 - 1,H - 1) = VR;
          //strcpy(action, "LO-REDUCTION   ");
        }

        for (i = 0; i < n; i++)
          Bvec[i] = (1 - bet) * P(i,H - 1) + bet * P(i,C - 1);

        f = fminfn(n, Bvec, OS_parscale, OS_fnscale, set, dim);

        if (!is_finite(f)) f = big;
        funcount = funcount + 1;

        if (f < P(n1 - 1,H - 1)) {
          for (i = 0; i < n; i++)
            P(i,H - 1) = Bvec[i];

          P(n1 - 1,H - 1) = f;
        } else {
          if (VR >= VH) {
            //strcpy(action, "SHRINK         ");
            calcvert = true;
            size = 0.0;

            for (j = 0; j < n1; j++) {
              if (j + 1 != L) {
                for (i = 0; i < n; i++) {
                  P(i,j) = bet * (P(i,j) - P(i,L - 1)) + P(i,L - 1);
                  size += abs(P(i,j) - P(i,L - 1));
                }
              }
            }

            if (size < oldsize) {
              oldsize = size;
            } else {
              Rcpp::Rcout << "FAILED sizes." << std::endl;
              fail = 10;
              break;
            }
          }
        }
      }
    } while (funcount <= maxit);
  }

  if (trace) {
    Rprintf("Exiting from Nelder Mead minimizer\n");
    Rprintf("    %d function evaluations used\n", funcount);
  }

  Fmin = P(n1 - 1,L - 1);
  for (i = 0; i < n; i++)
    X[i] = P(i,L - 1);

  if (funcount > maxit) fail = 1;

  Rcpp::Rcout << "Function count: " << funcount << std::endl;
  return Rcpp::List::create(
    _("value") = Fmin,
    _("ifail") = fail,
    _("fncount") = funcount,
    _("opar") = X
  );
}


///* par fn gr method options */
//List optim(SEXP call, SEXP op, SEXP args, SEXP rho) { //tmp, SEXP rho

// [[Rcpp::export]]
Rcpp::List optim_nm_cor(
  Rcpp::NumericVector par,
  List options,
  List args,
  List parArgs,

  double slower,
  double supper
) {
  std::string method;
  int i, npar=0, trace=0, maxit;
  int fncount = 0;
  double  val = 0.0;
  double abstol, reltol;
  double alpha, beta, gamma;
  double fnscale = 1;

  Rcpp::NumericVector dpar, opar, calc_par;
  Rcpp::NumericVector parscale;
  Rcpp::NumericVector OS_parscale;

  List argArgs = Rcpp::as<List>(args["args"]);
  List set = Rcpp::as<List>(argArgs["set"]);
  int dim = Rcpp::as<int>(argArgs["dim"]);


  npar = par.size();
  dpar = NumericVector(npar);
  opar = NumericVector(npar);
  calc_par = NumericVector(npar);
  OS_parscale = NumericVector(npar);

  if(options.containsElementNamed("trace")) {
    trace = options["trace"];
  }
  if(options.containsElementNamed("fnscale"))
    fnscale = options["fnscale"];

  NumericVector toRep = NumericVector::create(.1);
  OS_parscale = rep_each(toRep, npar);
  if(options.containsElementNamed("parscale")) {
    OS_parscale = options["parscale"];
  }
  if (OS_parscale.size() != npar) {
    std::range_error("'parscale' is of the wrong length");
  }

  for (i = 0; i < npar; i++)
    dpar[i] = par[i] / OS_parscale[i];

  abstol = -datum::inf;
  if(options.containsElementNamed("abstol"))
    abstol = options["abstol"];

  reltol = (double) sqrt(std::numeric_limits<double>::epsilon());
  if(options.containsElementNamed("reltol"))
    reltol = options["reltol"];

  maxit = 5000;
  if(options.containsElementNamed("maxit"))
    maxit = options["maxit"];

  alpha = 1.0;
  if(options.containsElementNamed("alpha"))
    alpha = (double) options["alpha"];

  beta = 0.5;
  if(options.containsElementNamed("beta"))
    beta = (double) options["beta"];

  gamma = 2.0;
  if(options.containsElementNamed("gamma"))
    gamma = (double) options["gamma"];

  Rcpp::Rcout << "Call NM-min!" << std::endl;
  List nmminRes = nmmin_c(
    npar, dpar, opar,
    val, abstol, reltol,
    OS_parscale, fnscale,
    alpha, beta, gamma, trace, fncount, maxit,
    set, dim
  );

  opar = nmminRes["opar"];
  for (i = 0; i < npar; i++)
    calc_par[i] = opar[i] * OS_parscale[i];

  val = (double) nmminRes["value"];
  fncount = nmminRes["fncount"];

  List toReturn = List::create(
    _("par") = calc_par,
    _("value") = val * fnscale,
    _("counts") = NumericVector::create(fncount, -1),
    _("convergence") = nmminRes["ifail"]
  );

  Rcpp::Rcout << "NM-min done." << std::endl;

  return toReturn;//  return res;
}


