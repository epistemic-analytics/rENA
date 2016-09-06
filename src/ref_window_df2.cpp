//'
// [[Rcpp::depends(RcppArmadillo)]]

#include <RcppArmadillo.h>
#include <Rcpp.h>
using namespace Rcpp;
using namespace arma;

arma::vec vector_to_ut(arma::mat v) {
  int vL = v.size();
  int vS = ( (vL * (vL + 1)) / 2) - vL ;
  int s = 0;
  arma::vec vR( vS );
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
    DataFrame v,
    CharacterVector nms = CharacterVector::create(),
    int windowSize = 0,
    bool append = false
) {
  int vRows = v.nrows();
  int AmLength = 0;
  if( nms.length() == 0 ) {
    AmLength = ( (v.size() * (v.size() + 1)) / 2) - v.size() ;
  } else {
    AmLength = nms.length();
  }

  // Matrix to be returned as DataFrame.
  IntegerMatrix Am(vRows, AmLength);
  arma::mat Am_mat(vRows, AmLength);

  IntegerMatrix v_AsMatrix(vRows,v.size());
  IntegerMatrix v_AsMatrix_window(vRows, (append)?(AmLength+v.size()):AmLength);
  for (int i=0; i<v.size();i++) {
    v_AsMatrix(_,i)=NumericVector(v[i]);
  }

  for(int row = 0; row < vRows; row++) {
    IntegerMatrix currRow = v_AsMatrix( Range( (row-windowSize>=0)?(row-windowSize):0,row ), _ );

    arma::mat currRowSummed = arma::sum(Rcpp::as<arma::mat>(currRow));
    arma::vec toUT = vector_to_ut(currRowSummed);

    if(windowSize > 0 && row-1>=0) {
      IntegerMatrix currRow_refs = v_AsMatrix( Range( (row-windowSize>=0)?(row-windowSize):0,(row-1>0)?row-1:0 ), _ );
      arma::mat currRow_refsSummed = arma::sum(Rcpp::as<arma::mat>(currRow_refs));
      arma::vec toUT_refs = vector_to_ut(currRow_refsSummed);

      v_AsMatrix_window(row, _) = Rcpp::as<IntegerMatrix>(wrap(toUT-toUT_refs));
    } else {
      v_AsMatrix_window(row, _) = Rcpp::as<IntegerMatrix>(wrap(toUT));
    }
    if(append == true) {
      for(int z = 0; z < v.size(); z++) {
        v_AsMatrix_window(row, AmLength+z) = currRowSummed[z]; //Rcpp::as<IntegerMatrix>(wrap(currRowSummed));
      }
    }
  }

  //if(append == false){
    DataFrame df(v_AsMatrix_window);
    return df;
  //} else {
  //  for(int z = 0; z < v.size(); z++) {
  //    v_AsMatrix_window( _, AmLength+z) = v_AsMatrix(_, z);
  //  }
    //DataFrame df = DataFrame::create(v_AsMatrix, v_AsMatrix_window);
  //  DataFrame df(v_AsMatrix_window);
  //  return df;
  //}
}
