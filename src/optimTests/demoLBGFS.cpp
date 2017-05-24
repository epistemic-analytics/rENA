// [[Rcpp::plugins(cpp11)]]
// [[Rcpp::depends(RcppEigen)]]
// [[Rcpp::depends(RcppNumerical)]]

#include <RcppArmadillo.h>
//#include <RcppNumerical.h>
//#include "LBFGS.h"
//#include "LBFGS.cpp"

#include <iostream>
#include "cppoptlib/meta.h"
#include "cppoptlib/problem.h"
#include "cppoptlib/boundedproblem.h"
#include "cppoptlib/solver/lbfgsbsolver.h"

using namespace Rcpp;
using namespace arma;
// using namespace Numer;
using namespace std;

using namespace cppoptlib;
using Eigen::VectorXd;



struct asset_info {
  double sum, sum2, stdev;
};

//[correlation matrix](http://en.wikipedia.org/wiki/Correlation_and_dependence).
// n,sX,sY,sXY,sX2,sY2
// cor = ( n * sXY - sX * sY ) / ( sqrt(n * sX2 - sX^2) * sqrt(n * sY2 - sY^2) )
inline asset_info compute_asset_info(
  const NumericMatrix& mat,
  const int icol, const int rstart, const int rend
) {
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

namespace cppoptlib {

template<typename T>
class Corr : public BoundedProblem<double> {
private:
  Rcpp::List set;
  int dim;
  NumericVector parscale;
  int n;
  double fnscale;
  NumericVector res;
  NumericVector dpar;
public:
  //int& count = 0;
  using Superclass = BoundedProblem<T>;
  // using typename cppoptlib::Problem<double>::Scalar;
  //using typename cppoptlib::Problem<double>::TVector;
  using typename Superclass::TVector;
  // using typename Superclass::Scalar;
  void init() {
    //count = 0;
    n = set["N"];
    // res = NumericVector(n);
    // dpar = NumericVector(n);
    fnscale = -1.0;
  };

  Corr(
    const Rcpp::List& set_,
    const TVector &l,
    const TVector &u
    ,const int& dim_
    ,const NumericVector& parscale_
  ):
    Superclass(l, u),
    set(set_),
    dim(dim_),
    parscale(parscale_)
  {
    init();
  }
  double correlation(arma::vec x) {
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
    return cc(1,0);
  }
  double value(const TVector &guess_) {
    int i;

    arma::vec x(guess_.size());
    for(i = 0; i < guess_.size(); i++) {
      dpar[i] = guess_[i] / parscale[i];
      x[i] = dpar[i] * parscale[i];
    }

    return correlation(x);
  }
  void gradient(const TVector &guess_, TVector &grad) {
    int i;
    double eps, epsused, tmp, val1, val2;
    NumericVector toRep, ndeps, lower, upper;

    arma::vec x(guess_.size());
    for(i = 0; i < guess_.size(); i++) {
      dpar[i] = guess_[i]; // / parscale[i];
      x[i] = dpar[i] * parscale[i];
    }

    toRep = NumericVector::create(1e-3);
    ndeps = rep_each(toRep, n);

    lower = NumericVector::create(n, -3);
    lower = rep_each(toRep, n);

    toRep = NumericVector::create(3);
    upper = rep_each(toRep, n);

    double s;
    Rcpp::Rcout << "grad1: " << grad.transpose() << std::endl;
    for (i = 0; i < n; i++) {
      epsused = eps = ndeps[i];

      int l = -3 / parscale[i];
      int u = 3 / parscale[i];

      tmp = x[i] + eps;
      if (tmp > u) {
        tmp = u;
        epsused = tmp - x[i];
      }
      x[i] = tmp * parscale[i];
      s = correlation(x); // set, dim);
      val1 = s / fnscale;

      tmp = x[i] - eps;
      if (tmp < l) {
        tmp = l;
        eps = x[i] - tmp;
      }
      x[i] = tmp * parscale[i];
      s = correlation(x); // set, dim);
      val2 = s / fnscale;

      grad[i] = (val1 - val2)/(epsused + eps);

      x[i] = guess_[i]; // * parscale[i];
    }
    Rcpp::Rcout << "grad2: " << grad.transpose() << std::endl;
    //guess_ = Rcpp::as<Eigen::VectorXd>(Rcpp::as<NumericVector>(x));
    // for(i = 0; i < guess_.size(); i++) {
    //   guess_[i] = x[i];
    // }
  }
};

} // END OF NAMESPACE

// class Correlation: public MFuncGrad {
// private:
//   Rcpp::List set;
//   int dim;
//   int n;
//   NumericVector parscale;
//   double fnscale;
//   // NumericVector initialGuess;
//   NumericVector res;
//   NumericVector dpar;
// public:
//   int& count;
//
//   void init() {
//     // Rcpp::Rcout << "Initializing the Correlation." << std::endl;
//     //int i;
//     count = 0;
//     n = set["N"];
//     res = NumericVector(n);
//     dpar = NumericVector(n);
//
//     // for(i = 0; i < n; i++) {
//     //   dpar[i] = initialGuess[i] / parscale[i];
//     //   res[i] = dpar[i] / parscale[i];
//     // }
//   };
//
//   Correlation(
//     const Rcpp::List& set_,
//     const int& dim_,
//     const NumericVector& parscale_,
//     const double& fnscale_,
//     int& count_
//   ):
//     set(set_), dim(dim_),
//     parscale(parscale_), fnscale(fnscale_),
//     count(count_)
//     //,initialGuess(initialGuess_)
//   {
//     init();
//   }
//
//   double correlation(arma::vec x) {
//     arma::mat dists = set["rotation_dists"];
//     arma::mat t_pair_dists = dists.col(dim);
//     arma::mat normed = set["data.normed"];
//
//     arma::uvec NtriOne = set["n1"];
//     arma::uvec NtriTwo = set["n2"];
//     arma::uvec KtriOne = set["k1"];
//     arma::uvec KtriTwo = set["k2"];
//
//     arma::mat mps = trans(((x(NtriOne) + x(NtriTwo)) / 2));
//
//     arma::mat multRes = normed * mps.t();
//     arma::mat centroids = multRes / sum(normed, 1);
//     arma::mat dcentroids = centroids(KtriOne) - centroids(KtriTwo);
//
//     arma::mat cmat2(t_pair_dists.n_rows, 2);
//     cmat2.col(0) = t_pair_dists;
//     cmat2.col(1) = dcentroids;
//
//     NumericMatrix cc = c_cor(Rcpp::wrap(cmat2));
//     return cc(1,0);
//   };
//
//   double f_grad( Constvec& guess_, Refvec grad) {
//     // Rcpp::Rcout << "guess: " << guess_ << std::endl;
//
//     int i;
//     double eps, epsused, tmp, val1, val2;
//     NumericVector toRep, ndeps, lower, upper;
//
//     arma::vec x(guess_.size());
//     for(i = 0; i < guess_.size(); i++) {
//       dpar[i] = guess_[i] / parscale[i];
//       x[i] = dpar[i] * parscale[i];
//     }
//
//     toRep = NumericVector::create(1e-3);
//     ndeps = rep_each(toRep, n);
//
//     lower = NumericVector::create(n, -3);
//     lower = rep_each(toRep, n);
//
//     toRep = NumericVector::create(3);
//     upper = rep_each(toRep, n);
//
//     double s;
//     for (i = 0; i < n; i++) {
//       epsused = eps = ndeps[i];
//
//       int l = -3 / parscale[i];
//       int u = 3 / parscale[i];
//
//       tmp = guess_[i] + eps;
//       if (tmp > u) {
//         tmp = u;
//         epsused = tmp - guess_[i];
//       }
//       x[i] = tmp * parscale[i];
//       s = correlation(x); // set, dim);
//       val1 = s / fnscale;
//
//       tmp = guess_[i] - eps;
//       if (tmp < l) {
//         tmp = l;
//         eps = guess_[i] - tmp;
//       }
//       x[i] = tmp * parscale[i];
//       s = correlation(x); // set, dim);
//       val2 = s / fnscale;
//
//       grad[i] = (val1 - val2)/(epsused + eps);
//
//       x[i] = dpar[i] * parscale[i];
//     }
//
//     // toRep = NumericVector::create(1);
//     // NumericVector gradNV = rep_each(toRep, n);
//     // grad = Rcpp::as<Eigen::VectorXd>(gradNV); //runif(n, -1,1));
//
//     double cc = correlation(x);
//     // Rcpp::Rcout << "grad " << grad << std::endl;
//     count += 1;
//     return abs(cc);
//   }
// };

// List optim_lbfgs_2(
//     MFuncGrad& f, Refvec x, double& fx_opt,
//     const int maxit = 3000,
//     //const double& eps_f = 1e-6
//     const double& eps_f = 1e-6
//   , const double& eps_g = 1e-5
// )
// {
//   // Create functor
//   LBFGSFun fun(f);
//
//   // Prepare parameters
//   LBFGSpp::LBFGSParam<double> param;
//   param.epsilon        = eps_g;
//   param.past           = 0;
//   param.delta          = eps_f;
//   param.max_iterations = maxit;
//   param.max_linesearch = 300;
//   param.linesearch     = LBFGSpp::LBFGS_LINESEARCH_BACKTRACKING;
//
//   // Solver
//   LBFGSpp::LBFGSSolver2<double> solver(param);
//
//   int status = 0;
//   Eigen::VectorXd xx(x.size());
//   xx.noalias() = x;
//
//   try {
//     Rcpp::Rcout << "MINIMIZE!" << std::endl;
//     solver.minimize(fun, xx, fx_opt);
//   } catch(const std::exception& e) {
//     Rcpp::Rcout << "error: " << e.what() << std::endl;
//     status = -1;
//     Rcpp::warning(e.what());
//   }
//
//   x.noalias() = xx;
//
//   return List::create(_("status") = status, _("res") = x);
// }
//
//
// Rcpp::NumericMatrix optim_test(Rcpp::List set) {
//   int N, num_samples, num_dims, i, j, pass = 0;
//
//   Rcpp::NumericVector toRep, OS_parscale;
//   Rcpp::NumericMatrix resultMatrix;
//
//
//   N = set["N"];
//   num_samples = set["samples"];
//   num_dims = set["dims"];
//   Rcpp::Rcout << "N: " << N << std::endl;
//   resultMatrix = Rcpp::NumericMatrix( N, 1); //(num_samples*num_dims) );
//   for(i = 0; i < 1; i++) {
//     for(j = 0; j < 1; j++) {
//       Rcpp::NumericVector resultVector = Rcpp::NumericVector::create(N); //+2);
//       toRep = NumericVector::create(1);
//       OS_parscale = rep_each(toRep, N);
//       int count = 0;
//
//       Rcpp::NumericVector initialGuess = runif(N,-3,3);
//       Eigen::VectorXd x(N); // = Rcpp::as<Eigen::VectorXd>(initialGuess); //.size());
//       for(int k=0; k < x.size(); k++){
//         x[k] = initialGuess[k];
//       }
//       double fopt;
//
//       Rcpp::Rcout << "INITG: " << initialGuess << std::endl;
//       Correlation c(set, i, OS_parscale, -1, count);
//       List res = optim_lbfgs_2(c, x, fopt);
//       resultVector = (x);
//       // resultVector.push_back( fopt );
//       // resultVector.push_back( i+1 );
//       resultMatrix(_ , pass) = resultVector;
//
//       Rcpp::Rcout << "COUNT: " << count << std::endl;
//       NumericVector resVes = Rcpp::as<NumericVector>(res["res"]);
//       Rcpp::Rcout << "RES: " << resVes << std::endl;
//       pass = pass + 1;
//     }
//   }
//
//   return resultMatrix;
// }


NumericVector optim_test_2(List set) {
  int N = set["N"];
  typedef double T;
  typedef cppoptlib::Corr<T> CORR;
  typedef typename CORR::TVector TVector;

  NumericVector toRep = NumericVector::create(1);
  NumericVector OS_parscale = rep_each(toRep, N);
  // const Rcpp::List& set_,
  // const int& dim_,
  // const NumericVector& parscale_,
  // const double& fnscale_,
  // int& count_
  TVector lower = (TVector::Ones(N)*-3);
  TVector upper = (TVector::Ones(N)*3);
  CORR f(set, lower, upper, 1, OS_parscale);

  LbfgsbSolver<CORR> solver;

  Rcpp::NumericVector initialGuess = runif(N,-3,3);
  Eigen::VectorXd x(N); // = Rcpp::as<Eigen::VectorXd>(initialGuess); //.size());
  for(int k=0; k < x.size(); k++){
    x[k] = initialGuess[k];
  }

  Rcpp::Rcout << "Initial Guess: " << x.transpose() << std::endl;
  solver.minimize(f, x);
  Rcpp::Rcout << "argmin      " << x.transpose() << std::endl;
  Rcpp::Rcout << "f in argmin " << f(x) << std::endl;
  return 0;
}

/*** R
Sys.setenv("PKG_CXXFLAGS"="-std=c++11")
# res = optim_test(e_list)
getwd()
load('../rENA.RData');
# optim_test_2(e_list)
*/
