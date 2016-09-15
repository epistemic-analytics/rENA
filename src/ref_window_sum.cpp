//'
// [[Rcpp::depends(RcppArmadillo)]]

#include <RcppArmadillo.h>
#include <Rcpp.h>
using namespace Rcpp;
using namespace arma;

arma::ivec vector_to_ut(arma::imat v) {
  int vL = v.size();
  int vS = ( (vL * (vL + 1)) / 2) - vL ;
  arma::ivec vR( vS, fill::zeros );
  int s = 0;
  for( int i = 2; i <= vL; i++ ) {
    for (int j = 0; j < i-1; j++ ) {
      vR[s] = v[j] * v[i-1];
      s++;
    }
  }
  return vR;
}

//' @param v - A dataframe
//' @param nms - A vector of characters used for colnames of returned DataFrame
//' @export
// [[Rcpp::export]]
DataFrame ref_window_sum(
    DataFrame df
) {
  int dfCols = df.size();
  int dfRows = df.nrows();

  arma::imat df_CoOccurred(dfRows, dfCols, fill::zeros);
  arma::imat df_AsMatrix2(dfRows, dfCols, fill::zeros);

  for (int i=0; i<dfCols;i++) {
    df_AsMatrix2.col(i) = Rcpp::as<arma::ivec>(df[i]);
  }

  return(sum(df_AsMatrix2));
}
