//'
// [[Rcpp::depends(RcppArmadillo)]]

#include <RcppArmadillo.h>
#include <Rcpp.h>
using namespace Rcpp;
using namespace arma;

arma::vec vector_to_ut(arma::mat v) {
  int vL = v.size();
  int vS = ( (vL * (vL + 1)) / 2) - vL ;
  arma::vec vR( vS, fill::zeros );
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
DataFrame ref_window_df(
    DataFrame df,
    int windowSize = 0,
    bool binary = true,
    bool useDiaganol = false
) {
  int dfRows = df.nrows();
  int dfCols = df.size();
  int numCoOccurences = ( (dfCols * (dfCols + 1)) / 2) - ((!useDiaganol)?dfCols:0);

  arma::mat df_CoOccurred(dfRows, numCoOccurences, fill::zeros);

  arma::mat df_AsMatrix2(dfRows, dfCols, fill::zeros);
  for (int i=0; i<dfCols;i++) {
    df_AsMatrix2.col(i) = Rcpp::as<arma::vec>(df[i]);
  }

  for(int row = 0; row < dfRows; row++) {
    arma::mat currRows2 = df_AsMatrix2( span( (row-windowSize>=0)?(row-windowSize):0,row ), span::all );
    //IntegerMatrix currRows = df_AsMatrix( Range( (row-windowSize>=0)?(row-windowSize):0,row ), _ );
    //Rcpp::Rcout << "rows2:\n" << currRows2 << std::endl;

    //arma::mat currRowsSummed = arma::sum(Rcpp::as<arma::mat>(currRows));
    arma::mat currRowsSummed = arma::sum(currRows2);
    arma::vec toUT = vector_to_ut(currRowsSummed);

    if(windowSize > 0 && row-1>=0) {
      //IntegerMatrix currRow_refs = df_AsMatrix( Range( (row-windowSize>=0)?(row-windowSize):0,(row-1>0)?row-1:0 ), _ );
      arma::mat currRows2_refs = df_AsMatrix2( span( (row-windowSize>=0)?(row-windowSize):0,(row-1>0)?row-1:0 ), span::all );

      //arma::mat currRow_refsSummed = arma::sum(Rcpp::as<arma::mat>(currRows2_refs));
      arma::mat currRow_refsSummed = arma::sum(currRows2_refs);
      arma::vec toUT_refs = vector_to_ut(currRow_refsSummed);
      arma::vec toUT_subs = toUT - toUT_refs;

      df_CoOccurred.row(row) = trans(toUT_subs);
    } else {
      df_CoOccurred.row(row) = trans(toUT);
    }
  }

  if(binary == true) {
    df_CoOccurred.elem( find(df_CoOccurred > 0) ).ones();
  }

  return wrap(df_CoOccurred);
}
