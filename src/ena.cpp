// [[Rcpp::depends(RcppArmadillo)]]

#include <iostream>
#include <vector>
#include <ctime>
#include <algorithm>
#include <iterator>
#include <cmath>
#include <RcppArmadillo.h>

using namespace Rcpp;
using namespace arma;
using namespace std;


NumericMatrix toNumericMatrix(DataFrame x) {
  int nRows=x.nrows();
  NumericMatrix y(nRows,x.size());
  for (int i=0; i<x.size();i++) {
    y(_,i)=NumericVector(x[i]);
  }
  return y;
}

//' Sphere norm
//' @title Sphere norm
//' @description TBD
//' @param dfM Dataframe
//' @export
// [[Rcpp::export]]
NumericMatrix fun_sphere_norm(DataFrame dfM) {
  NumericMatrix m = toNumericMatrix(dfM);

  int rows = m.nrow();
  int cols = m.ncol();
  NumericMatrix output(rows, cols);
  std::fill(output.begin(), output.end(), 0);

  for (int p = 0; p < rows; p++) {
    // Calculate the length of the vector ro  w
    NumericVector squared = Rcpp::pow(m.row(p),2);
    double squaredSum = Rcpp::sum(squared);
    double root = std::sqrt(squaredSum);

    if (root > 0) {
      output.row(p) = ( m.row(p) / root );
    }
  }

  return output;
}


//' Non sphere norm
//'
//' @title Non sphere norm
//' @description TBD
//' @param dfM Dataframe
//' @export
// [[Rcpp::export]]
NumericMatrix fun_skip_sphere_norm(DataFrame dfM) {
  NumericMatrix m = toNumericMatrix(dfM);

  int nrows = m.nrow();
  double largestRowVectorLength = 0;

  for(int rowNum=0; rowNum < nrows; rowNum++) {
    NumericVector squared = Rcpp::pow(m.row(rowNum),2);
    double squaredSum = Rcpp::sum( squared );
    double root = std::sqrt( squaredSum );

    largestRowVectorLength = std::max(largestRowVectorLength, root);
  }
  m = m / largestRowVectorLength;

  return(m);
}

// [[Rcpp::export]]
Rcpp::NumericMatrix center_data_c(arma::mat values) {
  arma::mat centered = values.each_row() - mean(values);
  return Rcpp::wrap(centered);
}

// [[Rcpp::export]]
arma::umat triIndices(int len, int row = -1) {
  int vL = len;
  int vS = ( (vL * (vL + 1)) / 2) - vL ;
  int s = 0;

  arma::umat vR = arma::umat(2, vS, fill::zeros);
  arma::umat vRone = arma::umat(1, vS, fill::zeros);
  for( int i = 2; i <= vL; i++ ) {
    for (int j = 0; j < i-1; j++ ) {
      vR(0, s) = j;
      vR(1, s) = i-1;
      if(row == 0) {
        vRone[s] = j;
      } else if (row == 1) {
        vRone[s] = i -1;
      }
      s++;
    }
  }

  if(row == -1) {
    return vR;
  } else {
    return vRone;
  }
}

// [[Rcpp::export]]
int getN(arma::mat normed) {
  return floor(0.5 + std::sqrt( 0.25 + 2 * normed.n_cols ));
}
