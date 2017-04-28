/// Sys.setenv("PKG_CXXFLAGS"="-std=c++11")

#include <iostream>
#include "/Users/clmarquart/Workspaces/untitled folder/CppNumericalSolvers/include/cppoptlib/meta.h"
#include "/Users/clmarquart/Workspaces/untitled folder/CppNumericalSolvers/include/cppoptlib/problem.h"
#include "/Users/clmarquart/Workspaces/untitled folder/CppNumericalSolvers/include/cppoptlib/solver/bfgssolver.h"
#include "/Users/clmarquart/Workspaces/untitled folder/CppNumericalSolvers/include/cppoptlib/solver/lbfgsbsolver.h"
#include "/Users/clmarquart/Workspaces/untitled folder/CppNumericalSolvers/include/cppoptlib/solver/lbfgsbsolver.h"
#include "/usr/local/Cellar/eigen/3.3.3/include/eigen3/Eigen/Core"

#include <RcppArmadillo.h>
#include <RcppEigen.h>

using namespace Rcpp;
using namespace arma;
// [[Rcpp::depends(RcppEigen)]]

//#include <Rcpp.h>

// using namespace Rcpp;
using namespace cppoptlib;
using namespace std;
using Eigen::VectorXd;

// Enable C++11 via this plugin (Rcpp 0.10.3 or later)

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


// using Vector = Eigen::Matrix<double, Eigen::Dynamic, 1>;

namespace cppoptlib {
class Rosenbrock : public Problem<double> {
public:
  using typename cppoptlib::Problem<double>::Scalar;
  using typename cppoptlib::Problem<double>::TVector;

  double value(const TVector &x) {
    const double t1 = (1 - x[0]);
    const double t2 = (x[1] - x[0] * x[0]);
    return   t1 * t1 + 100 * t2 * t2;
  }
  void gradient(const TVector &x, TVector &grad) {
    grad[0]  = -2 * (1 - x[0]) + 200 * (x[1] - x[0] * x[0]) * (-2 * x[0]);
    grad[1]  = 200 * (x[1] - x[0] * x[0]);
  }
};
}
namespace cppoptlib {
  template<typename T>
  class Correlation : public BoundedProblem<T> {
    // void init() {
    //   Rcpp::Rcout << "Init." << std::endl;
    // }

    public:
      using Superclass = BoundedProblem<T>;
      using typename cppoptlib::Problem<T>::Scalar;
      using typename cppoptlib::Problem<T>::TVector;

      const Rcpp::List set;
      const int dim;
    public:
      Correlation(const int& N, const Rcpp::List& set_, const int& dim_) :
         Superclass(N), set(set_), dim(dim_) { }

      T value(const TVector& x_) {
        arma::vec x(x_.size());
        for(int i = 0; i < x_.size(); i++) {
          x[i] = x_[i];
        }
        arma::mat dists = set["rotation_dists"];
        arma::mat t_pair_dists = dists.col(dim);
        arma::mat normed = set["data.normed"];

        arma::uvec NtriOne = set["n1"];
        arma::uvec NtriTwo = set["n2"];
        arma::uvec KtriOne = set["k1"];
        arma::uvec KtriTwo = set["k2"];

        arma::mat mps = trans(((x(NtriOne) + x(NtriTwo)) / 2));

        Rcpp::Rcout << "mps: " << mps << std::endl;
        arma::mat multRes = normed * mps.t();
        arma::mat centroids = multRes / sum(normed, 1);
        arma::mat dcentroids = centroids(KtriOne) - centroids(KtriTwo);

        arma::mat cmat2(t_pair_dists.n_rows, 2);
        cmat2.col(0) = t_pair_dists;
        cmat2.col(1) = dcentroids;

        NumericMatrix cc = c_cor(Rcpp::wrap(cmat2));

        return cc(1,0); //return 1;
      }
  };
}


typedef double T;
typedef cppoptlib::Correlation<T> COR;
typedef typename COR::TVector TVector;

arma::vec VectorToArma(COR::TVector v_) {
  arma::vec x;
  for(int i = 0; i < v_.size(); i++) {
    x[i] = v_(1,i);
  }
  return x;
}
COR::TVector ArmaToVector(arma::vec v_) {
  COR::TVector x;
  for(int i = 0; i < v_.size(); i++) {
    x[i] = v_(1,i);
  }
  return x;
}


// [[Rcpp::plugins(cpp11)]]
// [[Rcpp::export]]
int useAuto(Rcpp::NumericVector initialGuess, Rcpp::List set, int upper, int lower = 0) {
  // typedef double T;
  // typedef cppoptlib::NonNegativeLeastSquares<T> TNNLS;
  //typedef typename COR::TMatrix TMatrix;

  const int N = set["N"];
  const size_t DIM = N;
  // const size_t NUM = 10;
  // typedef double T;

  // create model X*b for arbitrary b
  // NonNegativeLeastSquares::TMatrix X = NonNegativeLeastSquares::TMatrix::Random(NUM, DIM);
  COR::TVector true_beta = COR::TVector::Random(DIM);
  // NonNegativeLeastSquares::TMatrix y = X*true_beta;

  //arma::vec values = { -1.0, 2.0, -0.123, 2.34 };
  // perform non-negative least squares
  COR::TVector initGuess = Rcpp::as<COR::TVector>(initialGuess);
  Rcpp::Rcout << "Init: " << initGuess << std::endl;
  COR f(N, set, 1);

  f.setLowerBound(TVector::Ones(DIM) * lower);
  if(upper != 0) {
    f.setUpperBound(TVector::Ones(DIM) * upper);
  }

  // create initial guess (make sure it's valid >= 0)
  //NonNegativeLeastSquares::TVector beta = NonNegativeLeastSquares::TVector::Random(DIM);
  //beta = (beta.array() < 0).select(-beta, beta);
  //std::cout << "true b  = " << true_beta.transpose() << "\tloss:" << f(true_beta) << std::endl;
  //std::cout << "start b = " << beta.transpose() << "\tloss:" << f(beta) << std::endl;

  // init L-BFGS-B for box-constrained solving
  // cppoptlib::LbfgsbSolver<COR> solver;
  cppoptlib::LbfgsbSolver<COR> solver;

  solver.minimize(f, initGuess);
  Rcpp::Rcout << "final loss: " << f(initGuess) << std::endl;
  Rcpp::Rcout << "final b = " << initGuess.transpose() << std::endl;
  // std::cout << "final b = " << beta.transpose() << "\tloss:" << f(beta) << std::endl;

  return 0;
}
