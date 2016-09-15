//'
// [[Rcpp::depends(RcppArmadillo)]]

#include <RcppArmadillo.h>
#include <Rcpp.h>
using namespace Rcpp;
using namespace arma;

vec vector_to_ut(mat v) {
  int vL = v.size();
  int vS = ( (vL * (vL + 1)) / 2) - vL ;
  int s = 0;
  vec vR( vS );
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
DataFrame ref_window_df2(
    DataFrame df,
    int windowSize = 0,
    bool binary = true,
    bool useDiaganol = false
) {
  int dfRows = df.nrows();
  int dfCols = df.size();
  int numCoOccurences = ( (dfCols * (dfCols + 1)) / 2) - ((!useDiaganol)?dfCols:0);

  //mat df_AsMatrix(dfRows,dfCols);
  mat df_CoOccurred(dfRows, numCoOccurences, fill::zeros);

  //for (int i=0; i<dfCols;i++) {
  //  df_AsMatrix(_,i) = Rcpp::as<mat>(df[i]);
  //}

  for(int row = 0; row < dfRows; row++) {
  //  IntegerMatrix currRow = df[(row-windowSize>=0)?(row-windowSize):0];
//
  //  mat currRowSummed = sum(Rcpp::as<arma::mat>(currRow));
  //  vec toUT = vector_to_ut(currRowSummed);
//
  //  if(windowSize > 0 && row-1>=0) {
  //    //IntegerMatrix currRow_refs = df[(row-windowSize>=0)?(row-windowSize):0,(row-1>0)?row-1:0)];
  //    //arma::mat currRow_refsSummed = arma::sum(Rcpp::as<arma::mat>(currRow_refs));
  //    //arma::ivec toUT_refs = vector_to_ut(currRow_refsSummed);
  //    vec toUT_subs = toUT; // - toUT_refs;
//
  //    df_CoOccurred.row(row) = trans(toUT_subs);
  //  } else {
  //    df_CoOccurred.row(row) = trans(toUT);
  //  }
  }
//
  //if(binary == true) {
  //  df_CoOccurred.elem( find(df_CoOccurred > 0) ).ones();
  //}

  return wrap(df); //_CoOccurred);
}
