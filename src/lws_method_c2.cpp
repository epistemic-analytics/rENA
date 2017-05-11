#include <RcppArmadillo.h>
#include <RcppEigen.h>

// [[Rcpp::depends(RcppEigen)]]

using namespace Rcpp;
using namespace arma;
using Eigen::Map;         // 'maps' rather than copies
using Eigen::MatrixXd;
using Eigen::MatrixXcd;   // variable size matrix, double precision
using Eigen::VectorXd;    // variable size vector, double precision
using Eigen::EigenSolver; // one of the eigenvalue solvers

class Offset {
private:
  int nrows, ncols, nmats ;

public:
  Offset( int nrows_, int ncols_, int nmats_) :
  nrows(nrows_),
  ncols(ncols_),
  nmats(nmats_){

  }

  int operator()( int i, int j, int k){
    return i + j * nrows + k * ( nrows * ncols ) ;
  }

} ;

//MatrixXcd
// [[Rcpp::export]]
void getEigenValues2(Rcpp::List adjMats, int numNodes) {
  int upperTriSize = (numNodes * (numNodes -1) / 2);
  int numDims = 2;

  MatrixXd M = MatrixXd::Zero(adjMats.length(), upperTriSize);
  for(int k = 0; k < adjMats.length(); k++) {
    MatrixXd currAdj = Rcpp::as<MatrixXd>(adjMats[k]);
    int ix = 0;

    // Update these loops so they don't iterate every cell
    for (int i = 0; i < numNodes; i++) {
      for (int j = 0; j < numNodes; j++) {
        if(i < j) {
          M(k,ix) = currAdj(i,j);
          ix = ix + 1;
        }
      }
    }
  }
  //Rcpp::Rcout << "M: " << M << std::endl;

  MatrixXd N = (M.transpose()*M);
  Rcpp::Rcout << "N : " << N << std::endl;
  EigenSolver<MatrixXd> es(N);
  MatrixXcd evs = es.eigenvectors();
  MatrixXcd t = M * evs.leftCols(numDims);

  // Rcpp::Rcout << "MT: " << N << std::endl;
  // Rcpp::Rcout << "EV: " << evs << std::endl;
  //Rcpp::Rcout << "t: " << t << std::endl;

  MatrixXd weights = MatrixXd::Zero(M.cols(), numNodes);
  for (int k = 0; k < M.cols(); k++) {
    MatrixXd currAdj = Rcpp::as<MatrixXd>(adjMats[k]);

    for (int i = 0; i < numNodes; i++) {
      for (int j = 0; j < numNodes; j++) {
        if ( i <= j ) {
          weights(k, i) += 0.5 * currAdj(i, j);
        } else {
          weights(k, i) += 0.5 * currAdj(j, i);
        }
      }
    }
  }
  //Rcpp::Rcout << "W: " << weights << std::endl;

  Rcpp::NumericVector delta = Rcpp::NumericVector ( Rcpp::Dimension(adjMats.length(), adjMats.length(), numDims) );
  Offset offset( adjMats.length(), adjMats.length(), numDims ) ;
  for(int a = 0; a < adjMats.length(); a++) {
    for(int b = 0; b < adjMats.length(); b++) {
      for(int m = 0; m < numDims; m++) {
        delta[ offset(a,b,m) ] = (t(a,m).real() - t(b,m).real()) ; //MatrixXd::Zero(M.cols(), numDims);
      }
    }
  }
  // Rcpp::Rcout << "Delta: " << delta << std::endl;

  MatrixXd gamma = MatrixXd::Zero(numDims, numNodes);
  for(int i = 0; i < numDims; i++) {
    for (int j = 0; j < numNodes; j++) {
      for(int a = 0; a < adjMats.length(); a++) {
        for(int b = 0; b < adjMats.length(); b++) {
          gamma(i,j) += delta[ offset(a,b,i) ] * ( weights(a,j) - weights(b,j) );
        }
      }
    }
  }
  //Rcpp::Rcout << "Gamma: " << gamma << std::endl;

  MatrixXd X = MatrixXd::Zero(numDims, numNodes);
  for(int i = 0; i < numDims; i++) {
    for (int j = 0; j < numNodes; j++) {
      X(i,j) = gamma(i,j) / gamma.row(i).norm();
    }
  }

  MatrixXd centroids = (X * weights.transpose()).transpose();


  double totalcorr = 0.0;
  for(int a = 0; a < adjMats.length(); a++) {
    for(int b = 0; b < adjMats.length(); b++) {
      if(a != b) {
        double n1 = (t.row(a) - t.row(b)).norm();
        double n2 = (centroids.row(a) - centroids.row(b)).norm();

        VectorXd numer1 = (t.row(a) - t.row(b)).real();
        VectorXd numer2 = (centroids.row(a) - centroids.row(b));

        double numer = numer1.dot(numer2);
        double denom = n1*n2;
        double corr = numer / denom;
        // Rcpp::Rcout << "Corr: " << corr << std::endl;
        totalcorr += corr;
      }
    }
  }

  double alphanum = 0 , alphadom = 0;
  for(int k = 0; k < adjMats.length(); k++) {
    for(int i = 0; i < numDims; i++) {
      alphanum += t(k,i).real() * centroids(k,i);
      alphadom += centroids(k,i) * centroids(k,i);
    }
  }
  double alpha = alphanum / alphadom;
  // Rcpp::Rcout << "Alpha: " << alpha << std::endl;
  X = alpha * X;
  centroids = alpha * centroids;
  // Rcpp::Rcout << "X: " << X << std::endl;
  // Rcpp::Rcout << "C: " << centroids << std::endl;
}

/*** R
#lws_optim_c(list(data = testNormed))
getEigenValues2(testAdjMats, 4)
*/
