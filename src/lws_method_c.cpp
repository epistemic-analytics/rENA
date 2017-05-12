#include <RcppEigen.h>

// [[Rcpp::depends(RcppEigen)]]

using namespace Rcpp;
using namespace Eigen;
using Eigen::Map;         // 'maps' rather than copies
using Eigen::MatrixXd;
using Eigen::MatrixXcd;   // variable size matrix, double precision
using Eigen::VectorXd;    // variable size vector, double precision
using Eigen::Vector3d;    // variable size vector, double precision
using Eigen::EigenSolver; // one of the eigenvalue solvers

class Offset {
private:
  int nrows, ncols; //, nmats ;

public:
  Offset( int nrows_, int ncols_ ) : //, int nmats_) :
    nrows(nrows_),
    ncols(ncols_)
    // ,nmats(nmats_)
  {
  }

  int operator()( int i, int j, int k){
    return i + j * nrows + k * ( nrows * ncols ) ;
  }

} ;

//MatrixXcd
// [[Rcpp::export]]
Rcpp::List linderoth_pos(Eigen::MatrixXd adjMats) {
  int upperTriSize = adjMats.cols();
  int numNodes = ( pow(ceil(sqrt(2*upperTriSize)),2) ) - (2*upperTriSize);
  int numDims = 2;

  MatrixXd M = adjMats;
  MatrixXd N = M.transpose() * M;

  EigenSolver<MatrixXd> es(N);
  MatrixXcd evs = es.eigenvectors();
  MatrixXcd t = M * evs.leftCols(numDims);

  MatrixXd weights = MatrixXd::Zero(adjMats.rows(), numNodes);
  Rcpp::Rcout << "UT size: " << upperTriSize << std::endl;
  for (int k = 0; k < adjMats.rows(); k++) {
    VectorXd currAdj = adjMats.row(k);
    int z = 0; // adjIndex
    for(int x = 0; x < numNodes-1; x++) {
      for(int y = 0; y <= x; y++) {
        weights(k,x+1) = weights(k,x+1) + (0.5*currAdj(z));
        weights(k,y) = weights(k,y) + (0.5 * currAdj(z));
        z = z + 1;
      }
    }
  }

  Rcpp::NumericVector delta = Rcpp::NumericVector ( Rcpp::Dimension(adjMats.rows(), adjMats.rows(), numDims) );
  Offset offset( adjMats.rows(), adjMats.rows() ); //, numDims ) ;
  for(int a = 0; a < adjMats.rows(); a++) {
    for(int b = 0; b < adjMats.rows(); b++) {
      for(int m = 0; m < numDims; m++) {
        delta[ offset(a,b,m) ] = (t(a,m).real() - t(b,m).real()) ; //MatrixXd::Zero(M.cols(), numDims);
      }
    }
  }

  MatrixXd gamma = MatrixXd::Zero(numDims, numNodes);
  for(int i = 0; i < numDims; i++) {
    for (int j = 0; j < numNodes; j++) {
      for(int a = 0; a < adjMats.rows(); a++) {
        for(int b = 0; b < adjMats.rows(); b++) {
          gamma(i,j) += delta[ offset(a,b,i) ] * ( weights(a,j) - weights(b,j) );
        }
      }
    }
  }

  MatrixXd X = MatrixXd::Zero(numDims, numNodes);
  for(int i = 0; i < numDims; i++) {
    for (int j = 0; j < numNodes; j++) {
      X(i,j) = gamma(i,j) / gamma.row(i).norm();
    }
  }

  MatrixXd centroids = (X * weights.transpose()).transpose();
  double totalcorr = 0.0;
  for(int a = 0; a < adjMats.rows(); a++) {
    for(int b = 0; b < adjMats.rows(); b++) {
      if(a != b) {
        double n1 = (t.row(a) - t.row(b)).norm();
        double n2 = (centroids.row(a) - centroids.row(b)).norm();

        VectorXd numer1 = (t.row(a) - t.row(b)).real();
        VectorXd numer2 = (centroids.row(a) - centroids.row(b));

        double numer = numer1.dot(numer2);
        double denom = n1*n2;
        double corr = numer / denom;
        totalcorr += corr;
      }
    }
  }

  double alphanum = 0 , alphadom = 0;
  for(int k = 0; k < adjMats.rows(); k++) {
    for(int i = 0; i < numDims; i++) {
      alphanum += t(k,i).real() * centroids(k,i);
      alphadom += centroids(k,i) * centroids(k,i);
    }
  }
  double alpha = alphanum / alphadom;

  X = alpha * X;
  centroids = alpha * centroids;
  // Rcpp::Rcout << "X: " << X << std::endl;
  // Rcpp::Rcout << "C: " << centroids << std::endl;

  return Rcpp::List::create(
    _("nodes") = X.transpose(),
    _("points") = t.real()
  );
}

/*** R
#linderoth_pos(4, enaset$data$normed)
#linderoth_pos(enaset$data$normed[1,4])
#linderoth_pos(testAdjMatsTris)
*/
