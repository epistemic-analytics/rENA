//'
// [[Rcpp::depends(RcppArmadillo)]]

#include <RcppArmadillo.h>
#include <Rcpp.h>
using namespace Rcpp;
using namespace arma;

NumericMatrix toNumericMatrix_(DataFrame x) {
  int nRows=x.nrows();
  NumericMatrix y(nRows,x.size());
  for (int i=0; i<x.size();i++) {
    y(_,i)=NumericVector(x[i]);
  }
  return y;
}

arma::rowvec vector_to_ut(arma::mat v) {
  int vL = v.size();
  int vS = ( (vL * (vL + 1)) / 2) - vL ;
  // arma::vec vR( vS, fill::zeros );
  arma::rowvec vR2( vS, fill::zeros );
  int s = 0;
  for( int i = 2; i <= vL; i++ ) {
    for (int j = 0; j < i-1; j++ ) {
      // vR[s] = v[j] * v[i-1];
      vR2[s] = v[j] * v[i-1];
      s++;
    }
  }
  return vR2;
}


//'

NumericVector vector_to_ut2(NumericVector v) {
  int vL = v.size();
  int vS = ( (vL * (vL + 1)) / 2) - vL ;
  // arma::vec vR( vS, fill::zeros );
  NumericVector vR( vS ); //, fill::zeros );
  int s = 0;
  for( int i = 2; i <= vL; i++ ) {
    for (int j = 0; j < i-1; j++ ) {
      // vR[s] = v[j] * v[i-1];
      vR[s] = v[j] * v[i-1];
      s++;
    }
  }
  return vR;
}


//'
// [[Rcpp::export]]
arma::mat rows_to_co_occurrences(DataFrame df) {
  int dfRows = df.nrows();
  int dfCols = df.size();
  int numCoOccurences = ( (dfCols * (dfCols + 1)) / 2) - dfCols;

  arma::mat df_AsMatrix2(dfRows, dfCols, fill::zeros);
  for (int i=0; i<dfCols;i++) {
    df_AsMatrix2.col(i) = Rcpp::as<arma::vec>(df[i]);
  }

  arma::mat df_CoOccurred(dfRows, numCoOccurences, fill::zeros);
  for(int row = 0; row < dfRows; row++) {
    df_CoOccurred.row(row) = vector_to_ut(df_AsMatrix2.row(row));
  }

  return df_CoOccurred;
}

//' @title ref_window_df
//' @name ref_window_df
//'
//' @param df A dataframe
//' @param windowSize Integer for number of rows in the stanza window
//' @param binary Logical, treat codes as binary or leave as weighted

// [[Rcpp::export]]
DataFrame ref_window_df(
    DataFrame df,
    int windowSize = 0,
    bool binary = true
) {
  int dfRows = df.nrows();
  int dfCols = df.size();
  int numCoOccurences = ( (dfCols * (dfCols + 1)) / 2) - dfCols;

  arma::mat df_CoOccurred(dfRows, numCoOccurences, fill::zeros);

  arma::mat df_AsMatrix2(dfRows, dfCols, fill::zeros);
  for (int i=0; i<dfCols;i++) {
    df_AsMatrix2.col(i) = Rcpp::as<arma::vec>(df[i]);
  }

  for(int row = 0; row < dfRows; row++) {
    /**
     * The rows in the current window. CurrentRow + Referrants == windowSize
     */
    arma::mat currRows2 = df_AsMatrix2( span( (row-(windowSize-1)>=0)?(row-(windowSize-1)):0,row ), span::all );
    arma::mat currRowsSummed = arma::sum(currRows2);
    arma::rowvec toUT = vector_to_ut(currRowsSummed);

    if(windowSize > 1 && row-1>=0) {
      //arma::mat currRows2_refs = df_AsMatrix2( span( (row-(windowSize-1)>=0)?(row-(windowSize-1)):0,(row-1>0)?row-1:0 ), span::all );
      arma::mat currRows2_refs = currRows2.head_rows(currRows2.n_rows-1);

      arma::mat currRow_refsSummed = arma::sum(currRows2_refs);
      arma::rowvec toUT_refs = vector_to_ut(currRow_refsSummed);
      arma::rowvec toUT_subs = toUT - toUT_refs;

      df_CoOccurred.row(row) = toUT_subs;
    } else {
      df_CoOccurred.row(row) = toUT;
    }
  }

  if(binary == true) {
    df_CoOccurred.elem( find(df_CoOccurred > 0) ).ones();
  }

  return wrap(df_CoOccurred);
}


//' @title ref_window_df2
//' @name ref_window_df2
//'
//' @param df A dataframe
//' @param windowSize Integer for number of rows in the stanza window
//' @param binary Logical, treat codes as binary or leave as weighted
//'

NumericMatrix ref_window_df2(
    DataFrame df,
    int windowSize = 1,
    bool binary = true
) {
  int dfRows = df.nrows();
  int dfCols = df.size();
  int numCoOccurences = ( (dfCols * (dfCols + 1)) / 2) - dfCols;

  NumericMatrix df_CoOccurred(dfRows, numCoOccurences);
  NumericMatrix df_asMatrix = toNumericMatrix_(df);

  for(int row = 0; row < dfRows; row++) {
    /** The rows in the CurrentWindow. CurrentRow + ReferringRows == windowSize */
    NumericMatrix currRows = df_asMatrix( Range( (row-(windowSize-1)>=0)?(row-(windowSize-1)):0,row ), _ );
    Rcpp::Rcout << "Window " << row << ":" << std::endl << currRows << std::endl;

    /** Sum of the entire CurrentWindow */
    NumericVector currRowsSummed1 = Rcpp::colSums(currRows);

    /**
     * The co-occurrences in the CurrentWindow as vector representing
     * the upper-triangle.
     */
    NumericVector toUT = vector_to_ut2(currRowsSummed1);

    /**
     * The ReferringRows in the CurrentWindow have to be calculating
     * separately, so they can then be subtracted from the CurrentWindow.
     */
    if(windowSize > 1 && row-1>=0) {
      /** Select ReferringRows for the CurrentWindow */
      NumericMatrix currRow_refs = df_asMatrix( Range( (row-(windowSize-1)>=0) ? (row-(windowSize-1)): 0, (row-1>0)?row-1:0 ), _ );
      Rcpp::Rcout << "Refs " << row << ":" << std::endl << currRow_refs << std::endl;

      /** Sum the ReferringRows for the CurrentWindow */
      NumericVector currRow_refsSummed = Rcpp::colSums(currRow_refs);
      // Rcpp::Rcout << "Sums " << row << ":" << std::endl << currRow_refsSummed << std::endl << std::endl;

      /**
      * The co-occurrences for the sum of ReferringRows as a vector representing
      * the upper-triangle.
      */
      NumericVector toUT_refs = vector_to_ut2(currRow_refsSummed);

      /**
       * Subtraction of ReferringRows from the CurrentWindow represents the
       * co-occurrences between the CurrentRow and any other Row in the
       * CurrentWindow
       */
      NumericVector toUT_subs = toUT - toUT_refs;

      df_CoOccurred.row(row) = toUT_subs;
    } else {
      //Rcpp::Rcout << "toUT1: " << toUT << std::endl;
      //arma::rowvec rowV(toUT);
      // Rcpp::Rcout << "toUT2: " << rowV << std::endl;
      // df_CoOccurred.row(row) = trans(toUT);
      df_CoOccurred.row(row) = toUT;
    }
  }

  if(binary == true) {
    //df_CoOccurred.elem( find(df_CoOccurred > 0) ).ones();
  }

  //Rcpp::Rcout << "CoOccur: " << df_CoOccurred << std::endl;
  return (df_CoOccurred);
}


//' @title ref_window_lag
//' @name ref_window_lag
//'
//' @param df A dataframe
//' @param windowSize Integer for number of rows in the stanza window
//' @param binary Logical, treat codes as binary or leave as weighted
// [[Rcpp::export]]
DataFrame ref_window_lag(
    DataFrame df,
    int windowSize = 0,
    bool binary = true
) {
  int dfRows = df.nrows();
  int dfCols = df.size();

  arma::mat df_LagSummed(dfRows, dfCols, fill::zeros);

  arma::mat df_AsMatrix2(dfRows, dfCols, fill::zeros);
  for (int i=0; i<dfCols;i++) {
    df_AsMatrix2.col(i) = Rcpp::as<arma::vec>(df[i]);
  }

  for(int row = 0; row < dfRows; row++) {
    arma::mat currRows2 = df_AsMatrix2( span( (row-(windowSize-1)>=0)?(row-(windowSize-1)):0,row ), span::all );
    arma::mat currRowsSummed = arma::sum(currRows2);

    df_LagSummed.row(row) = currRowsSummed;
  }

  return wrap(df_LagSummed);
}
