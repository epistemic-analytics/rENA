// [[Rcpp::depends(RcppArmadillo)]]

#include <RcppArmadillo.h>
#include <Rcpp.h>
using namespace Rcpp;
using namespace arma;

//' @param v - A dataframe
//' @param nms - A vector of characters used for colnames of returned DataFrame
DataFrame ref_window_df_old (
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

  for(int row = 0; row < vRows; row++) {
    int s = 0;

    for(int i = 2; i <= v.length(); i++) {
      for (int j = 0; j < i-1; j++ ) {
        IntegerVector vDF0 = v.at(j);
        IntegerVector vDF1 = v.at(i-1);
        Am(row, s) = vDF0.at(row) * vDF1.at(row);
        s++;
      }
    }
  }

  DataFrame df(Am);

  if(windowSize > 0) {
    IntegerMatrix Am_win( Am );
    //arma::mat Am_winX = Rcpp::as<arma::mat>(Am);
    arma::mat Am_winX = Rcpp::as<arma::mat>( Am );

    for(int row = 1; row < Am.rows(); row++ ) {
      IntegerVector rowVector = Am_win.row(row);

      IntegerMatrix windowMatrix = Am_win( Range( (row-windowSize>=0)?(row-windowSize):0,row), _ );
      IntegerMatrix windowRefMatrix = Am_win( Range( (row-windowSize>=0)?(row-windowSize):0,row-1), _ );

      Rcpp::Rcout << "Window Matrix:\n" << windowMatrix << std::endl;
      Rcpp::Rcout << "WinRef Matrix:\n" << windowRefMatrix << std::endl;

      arma::mat winMatrix = arma::sum(Rcpp::as<arma::mat>(windowMatrix));
      arma::mat winMatrixRef = arma::sum(Rcpp::as<arma::mat>(windowRefMatrix));
      arma::mat winMatrixSum = winMatrix - winMatrixRef;

      Rcpp::Rcout << winMatrixRef << std::endl << std::endl;

      Am_winX.row(row) = winMatrixSum;
    }

    if(append == false){
      df = DataFrame(Am_winX);
    } else {
      df = DataFrame(join_rows(Rcpp::as<arma::mat>( Am ), Am_winX));
    }
  }


  return df;
}
