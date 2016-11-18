// [[Rcpp::depends(RcppArmadillo)]]

#include <iostream>
#include <vector>
#include <ctime>
#include <algorithm>
#include <iterator>
#include <cmath>
#include <RcppArmadillo.h>
#include "/Users/clmarquart/Workspaces/RStudio2/rENA/src/simplex.h"
#include "/Users/clmarquart/Workspaces/RStudio2/rENA/src/optimizer.h"
//#include "/Users/clmarquart/Workspaces/RStudio2/rENA/src/optim.c"
//#include "cor.h"

using namespace Rcpp;
using namespace arma;
using namespace std;

template<class Con>
void printcon(const Con& c){
  //std::cout.precision(12);
  copy(c.begin(),c.end(),ostream_iterator<typename Con::value_type>(Rcpp::Rcout, "  "));
}

// [[Rcpp::export]]
int count_if(LogicalVector x) {
  int counter = 0;
  for(int i = 0; i < x.size(); i++) {
    if(x[i] == TRUE) {
      counter++;
    }
  }
  return counter;
}

// [[Rcpp::export]]
int vecmin(NumericVector x) {
  // Rcpp supports STL-style iterators
  NumericVector::iterator it = std::min_element(x.begin(), x.end());
  // we want the value so dereference
  return *it;
}

// [[Rcpp::export]]
int vecmax(NumericVector x) {
  // Rcpp supports STL-style iterators
  NumericVector::iterator it = std::max_element(x.begin(), x.end());
  // we want the value so dereference
  return *it;
}

// [[Rcpp::export]]
NumericVector logicalToColNums( LogicalVector lv ) {
  int size = lv.size();
  NumericVector nv(count_if(lv));

  int s=0;
  for ( int i=0; i<size; i++) {
    if(lv[i] == 1) {
      nv(s) = i;
      s++;
    }
  }

  return nv;
}

// [[Rcpp::export]]
NumericVector rowSumsC(NumericMatrix x) {
  int nrow = x.nrow(), ncol = x.ncol();
  NumericVector out(nrow);

  for (int i = 0; i < nrow; i++) {
    double total = 0;
    for (int j = 0; j < ncol; j++) {
      total += x(i, j);
    }
    out[i] = total;
  }
  return out;
}

class CorENA{
private:
  arma::mat dists ;
  arma::mat normed ;
  arma::mat x ;
  arma::uvec NtriOne ;
  arma::uvec NtriTwo ;
  arma::uvec KtriOne ;
  arma::uvec KtriTwo ;
  arma::mat corrs;
  int dim ;
public:
  CorENA( ) : dim(0) {}
  CorENA( int dim ) : dim(dim) {}
  CorENA(
    arma::mat dists,
    arma::mat normed,
    arma::uvec NtriOne,
    arma::uvec NtriTwo,
    arma::uvec KtriOne,
    arma::uvec KtriTwo,
    arma::mat corrs,
    int dim
  ) : dists(dists),
  normed(normed),
  NtriOne(NtriOne),
  NtriTwo(NtriTwo),
  KtriOne(KtriOne),
  KtriTwo(KtriTwo),
  corrs(corrs),
  dim(dim) {}

  //arma::mat
  //double operator()(vector<double> x){
  double operator()(vector<double> x) {
    return this->calc( arma::vec(x) );
  }

  double operator()(arma::vec x) {
    return this->calc(x);
  }

  double calc(arma::vec x) {
    arma::mat t_pair_dists = this->dists.col(this->dim);
    arma::mat mps = trans(((x(this->NtriOne) + x(this->NtriTwo)) / 2));
    arma::mat multRes = this->normed * mps.t(); //.row(0);
    arma::mat centroids = multRes / sum(this->normed, 1);
    arma::mat dcentroids = centroids(this->KtriOne) - centroids(this->KtriTwo);
    arma::mat c = cor(t_pair_dists, dcentroids, 0);

    //Rcpp::Rcout << "Vec x: " << x << std::endl;
    //Rcpp::Rcout << "dists: " << t_pair_dists << std::endl;
    //Rcpp::Rcout << "MPS * normed: " << multRes << std::endl;
    //Rcpp::Rcout << "Rowsum: " << sum(this->normed, 1) << std::endl;
    //Rcpp::Rcout << "Cents: " << centroids << std::endl;
    //Rcpp::Rcout << "DCents: " << dcentroids << std::endl;
    //Rcpp::Rcout << "cor: " << c << std::endl;


    return(c(0,0));
  }
};

//arma::vec coeff, arma::vec ti, arma::vec xi
class SOLN{
private:
  arma::mat w ;
  arma::mat ti ;
  arma::mat xi ;
public:
  SOLN(
    arma::mat w,
    arma::mat xi,
    arma::mat ti
  ) : w(w),
  ti(ti),
  xi(xi) {}

  double operator()(Vector2 x) {
    arma::vec v(2);
    v << x[0] << x[1];
    return this->calc( v );
  }

  double operator()(vector<double> x) {
    //Rcpp::Rcout << "Coeff: " << arma::vec(x) << std::endl;
    return this->calc( arma::vec(x) );
  }

  double operator()(arma::vec x) {
    return this->calc(x);
  }

  arma::uvec triIndices(int len, int row = 0) {
    int vL = len;
    int vS = ( (vL * (vL + 1)) / 2) - vL ;
    int s = 0;

    arma::umat vR = arma::umat(2, vS, fill::zeros);
    uvec vRone = uvec(vS);
    for( int i = 2; i <= vL; i++ ) {
      for (int j = 0; j < i-1; j++ ) {
        if(row == 0) {
          vR(0, s) = j;
          vRone[s] = j;
        } else {
          vR(1, s) = i-1;
          vRone[s] = i -1;
        }
        s++;
      }
    }
    return vRone;
  }

  arma::vec MPS(arma::mat x) {
    arma::rowvec xVec = x.t();
    arma::uvec CC1 = triIndices(xVec.size(), 0);
    arma::uvec CC2 = triIndices(xVec.size(), 1);
    arma::vec mps = ((xVec(CC1) + xVec(CC2)) / 2);
    return(mps);
  }

  double calc(arma::vec coeff) {
    //Rcpp::Rcout << "Coeff: " << coeff[0] << ", " << coeff[1] << std::endl;
    //arma::ivec coeffI = arma::ivec(coeff);
    arma::vec mps = MPS( (coeff[0]) + ( (coeff[1]) * this->xi) );
    //Rcpp::Rcout << "MPS: " << mps << std::endl;
    //Rcpp::Rcout << "xi: " << this->xi << std::endl;
    //arma::mat ww = trans(w);
    arma::vec ci = arma::vec(w.n_rows);
    for(int i=0; i < w.n_rows; i++) {
      ci[i] = sum(w.row(i) * mps) / sum(w.row(i)) ;
    }
    //Rcpp::Rcout << "CI: " << ci << std::endl;

    double ssd = sum(arma::pow((ci - this->ti), 2));

    //Rcpp::Rcout << "SSD: " << ssd << std::endl;

    return(ssd);
  }
};

// [[Rcpp::export]]
arma::mat fixIt(DataFrame df) {
  int dfRows = df.nrows();
  int dfCols = df.size();
  arma::mat m(dfRows, dfCols, fill::zeros);

  for (int i=0; i<dfCols;i++) {
    m.col(i) = Rcpp::as<arma::vec>(df[i]);
  }

  arma::mat output(dfRows, dfCols, fill::zeros);
  for (int p = 0; p < dfRows; p++) {
    //int vlength = ( sum(m[p,]^2) )^ (1/2);
    //if (!is.na (vlength)) {
    //  if (vlength>0) {output[p,]=(m[p,]/vlength)}
    //}
  }

  return(output);
}

// [[Rcpp::export]]
arma::mat sphere_norm(arma::mat m) {
  int rows = m.n_rows;
  arma::mat output(rows , m.n_cols, fill::zeros);

  for (int p = 0; p < rows; p++) {
    arma::vec vlength = pow( sum( pow(m.row(p),2), 1 ), 0.5);
    double vl = vlength(0);

    if (vl > 0) {
      output.row(p) = ( m.row(p) / vl );
    }
  }
  return output;
}

// [[Rcpp::export]]
arma::mat dont_sphere_norm(arma::mat m) {
  int nrows = m.n_rows;
  double largestRowVectorLength = 0;
  for(int rowNum=0; rowNum < nrows; rowNum++) {
    arma::vec currLength = pow( sum( pow(m.row(rowNum),2), 1 ), 0.5);
    double cl = currLength(0);
    largestRowVectorLength = std::max(largestRowVectorLength, cl);
  }

  m = m / largestRowVectorLength;
  return(m);
}

// [[Rcpp::export]]
arma::mat normIt(DataFrame df) {
  int dfRows = df.nrows();
  int dfCols = df.size();
  arma::mat m(dfRows, dfCols, fill::zeros);
  for (int i=0; i<dfCols;i++) {
    m.col(i) = Rcpp::as<arma::vec>(df[i]);
  }

  return arma::normalise(m, 2, 1);
}

// [[Rcpp::export]]
Rcpp::NumericMatrix pca(arma::mat m, int dims = 2) {
  //int dfRows = df.nrows();
  //int dfCols = df.size();

  //arma::mat m(dfRows, dfCols, fill::zeros);
  //for (int i=0; i<dfCols;i++) {
  //  m.col(i) = Rcpp::as<arma::vec>(df[i]);
  //}

  arma::mat pca;
  arma::mat score;
  arma::vec latent;
  arma::vec tsquared;
  arma::princomp(pca, score, latent, tsquared, m);

  if(pca.n_cols > dims) {
    pca = pca.head_cols(dims);
  }

  return Rcpp::wrap(pca);
}

// [[Rcpp::export]]
Rcpp::NumericMatrix centerData(arma::mat values) {
  arma::mat centered = values.each_row() - mean(values);
  return Rcpp::wrap(centered);
}

// [[Rcpp::export]]
Rcpp::NumericMatrix centerDataRotated(arma::mat centeredValues, arma::mat rotated) {
  arma::mat rotatedCentered = centeredValues * rotated;
  return Rcpp::wrap(rotatedCentered);
}

// [[Rcpp::export]]
Rcpp::NumericMatrix eq_pos(Rcpp::CharacterVector names, Rcpp::CharacterMatrix labels, arma::mat rotated, bool plusOne) {
  int numNames = names.size();

  arma::mat vals = arma::mat( size(rotated), fill::eye);
  arma::mat out = arma::mat(numNames, rotated.n_cols, fill::zeros);

  if(plusOne == true) {
    for (int p=0; p < numNames; p++) {
      Rcpp::CharacterVector topRow = labels(0, _);
      Rcpp::CharacterVector botRow = labels(1, _);
      for(int j=0; j < topRow.size(); j++) {
        if(topRow[j] == names[p] || botRow[j] == names[p]) {
          out(p, j) = 1;
        }
      }
    }

    out = (( (out * 2) * rotated ) / (numNames - 1) / 2);
  }

  return Rcpp::wrap(out);
}

// [[Rcpp::export]]
arma::uvec triIndices(int len, int row = 0) {
  int vL = len;
  int vS = ( (vL * (vL + 1)) / 2) - vL ;
  int s = 0;

  arma::umat vR = arma::umat(2, vS, fill::zeros);
  uvec vRone = uvec(vS);
  for( int i = 2; i <= vL; i++ ) {
    for (int j = 0; j < i-1; j++ ) {
      if(row == 0) {
        vR(0, s) = j;
        vRone[s] = j;
      } else {
        vR(1, s) = i-1;
        vRone[s] = i -1;
      }
      s++;
    }
  }
  return vRone; //.row(row);
}

// [[Rcpp::export]]
double getcor(
    arma::mat dists, arma::mat normed, arma::mat x,
    arma::uvec NtriOne, arma::uvec NtriTwo,
    arma::uvec KtriOne, arma::uvec KtriTwo,
    int dim = 0
) {
  arma::mat t_pair_dists = dists.col(dim);
  arma::mat mps = ((x(NtriOne) + x(NtriTwo)) / 2);
  arma::mat centroids = ((sum(normed, 0) % trans(mps)) - sum(normed, 0));
  arma::mat dcentroids = centroids(KtriOne); // - centroids(KtriTwo);

  double c = as_scalar(cor(t_pair_dists, dcentroids));

  return(c);
}

// [[Rcpp::export]]
//arma::vec
List single_optim(
    arma::mat normed, arma::mat dists,
    arma::mat rotated,
    arma::uvec NtriOne, arma::uvec NtriTwo,
    arma::uvec KtriOne, arma::uvec KtriTwo,
    int dim = 0, double N = 0.0
) {
  arma::mat coRes;
  CorENA co = CorENA(
    dists,
    normed,
    NtriOne,
    NtriTwo,
    KtriOne,
    KtriTwo,
    coRes,
    dim
  );

  NumericVector rands = runif(N, -3, 3);
  std::vector<double> rands_(N);

  int i;
  for(i = 0; i < rands.length(); i++) {
    rands_[i] = rands(i);;
  }
  //Rcpp::Rcout << "Rands: " << rands << std::endl;

  using BT::Simplex;
  arma::vec sim = Simplex(
     co
    ,rands_
    ,1E-5 //1E8*std::numeric_limits<double>::epsilon()
    ,std::vector<std::vector<double> >()
    //,1E5
  );

  sim = sim.tail(N);
  return List::create(
    _["positions"] = sim,
    _["correlation"] = co(sim)
  );
}

// [[Rcpp::export]]
int getN(arma::mat normed) {
  return floor(0.5 + sqrt( 0.25 + 2*normed.n_cols ));
}

// [[Rcpp::export]]
int getK(arma::mat normed) {
  return normed.n_rows;
}

// [[Rcpp::export]]
NumericMatrix do_opt(
    arma::mat normed,
    arma::mat dists,
    arma::mat rotated,
    int num_samples = 100, int num_dims = 2
) {
  double N = getN(normed);
  int K = getK(normed);

  uvec NtriOne = triIndices(N, 0);
  uvec NtriTwo = triIndices(N, 1);
  uvec KtriOne = triIndices(K, 0);
  uvec KtriTwo = triIndices(K, 1);

  NumericMatrix soRes(N+2, num_dims*num_samples);

  int r = 0;
  for(int i=0; i<num_dims; i++) {
    for(int j=0; j<num_samples; j++) {
      int s = 0;
      List nV = single_optim(normed, dists, rotated, NtriOne, NtriTwo, KtriOne, KtriTwo, i, N);
      NumericVector newVec = wrap(nV["positions"]);
      //double corr = nV["correlation"];

      int k;
      for(k=0; k < newVec.length(); k++) {
        soRes(k, r) = newVec[k]; //newVec;
        s++;
      }
      soRes(k, r) = nV["correlation"];
      soRes(k+1, r) = i;  //Tracks the dimension
      r++;
    }
  }

  return soRes;
}


// [[Rcpp::export]]
arma::mat getRotationDistances(arma::mat rotated) {
  int K = getK(rotated);
  uvec KtriOne = triIndices(K, 0);
  uvec KtriTwo = triIndices(K, 1);

  arma::mat pairDists = (rotated.rows(KtriOne) - rotated.rows(KtriTwo));

  return pairDists;
}

// [[Rcpp::export]]
Rcpp::List get_optimized_node_pos(
    arma::mat normedFiltered,
    NumericMatrix opted,
    int num_dims=2, int num_samples=3, int max_iter=1000,
    bool return_all = true
) {
  arma::uvec b = find(any(normedFiltered != 0, 1) > 0); //apply(normed, 1, function(z) !all(z==0))
  arma::mat normedNonZero = normedFiltered.rows(b);

  double N = getN(normedNonZero);
  int K = getK(normedNonZero);

  uvec NtriOne = triIndices(N, 0);
  uvec NtriTwo = triIndices(N, 1);
  uvec KtriOne = triIndices(K, 0);
  uvec KtriTwo = triIndices(K, 1);

  //arma::mat pairDists = getRotationDistances(rotatedFiltered);
  //NumericMatrix opted = Rcpp::wrap(dataOptim); //do_opt(normedFiltered, pairDists, rotatedFiltered, num_samples, num_dims);
  CharacterVector pc_names(num_dims);
  for(int i=0; i<num_dims; i++) {
    pc_names[i] = "PC" + std::to_string(i+1);
  }
  opted.attr("colnames") = pc_names;

  CharacterVector correlationRowNames(num_samples);
  for(int i=0; i<num_samples; i++) {
    correlationRowNames[i] = "Sample " + std::to_string(i+1);
  }

  NumericMatrix correlations = opted( Range(opted.nrow()-2, opted.nrow()-2), _ ); // Range(0,opted.ncol()-num_samples-1) );
  correlations.attr("dim") = Dimension(num_samples,num_dims);

  colnames(correlations) = pc_names;
  rownames(correlations) = correlationRowNames;

  CharacterVector iterNames(opted.ncol());
  NumericMatrix iterIndex(num_dims * num_samples, 2);
  for(int i=0; i<opted.ncol(); i++) {
    iterNames[i] = "PC_" + std::to_string((int) opted(opted.nrow() - 1, i)) + "_iter_"+ std::to_string((int) i);
    iterIndex(i, 0) = opted(opted.nrow() - 2, i);
    iterIndex(i, 1) = opted(opted.nrow() - 1, i);
  }

  arma::mat AllIters = Rcpp::as<arma::mat>(opted);
  AllIters = AllIters.rows(0, AllIters.n_rows - 3);
  arma::mat IterMeans = arma::mat(N, num_dims, fill::zeros);

  NumericVector dimRow = opted( opted.nrow() - 1, _ );

  int t=0;
  for( int i=0; i<num_dims; i++) {
    LogicalVector dimRowFilter = ( dimRow == i+1 );
    arma::vec vecs = Rcpp::as<arma::vec>(logicalToColNums(dimRowFilter));

    arma::mat rowsToSum2 = arma::mat(opted.nrow()-2, num_samples, fill::zeros);
    rowsToSum2 = AllIters(0, vecs(0), size(opted.nrow()-2, vecs.size()));

    arma::vec rowsMeaned = mean(rowsToSum2, 1);

    IterMeans.col( t ) = rowsMeaned; //.col(  );
    t++;
  }

  arma::mat centroids = arma::mat( K, AllIters.n_cols );

  for( int i=0; i<centroids.n_cols; i++ ) {
    arma::mat subbed = AllIters.rows(NtriOne);
    arma::mat subbedTwo = AllIters.rows(NtriTwo);
    arma::vec subbedComb = ( subbed.col(i) + (subbedTwo.col(i) / 2) );
    arma::vec subbedComb2 = normedNonZero * subbedComb;
    arma::vec summedRows = sum(subbedComb2, 1) / sum(normedNonZero, 1);

    centroids.col(i) = summedRows;
  }
  arma::mat centroid_dists = centroids.rows(KtriOne) - centroids.rows(KtriTwo);

  if(return_all == true) {
    //  e$opt_params = list(max_iterations = e$maxit,
    //  n_samples = e$num_samples,
    //  num_dims = e$num_dims)
    //  e$list_names = names(e)

    //  for(i in c("maxit", "num_samples", "i", "j", "i2", "j2"))
    //    e[[i]] = NULL
    return List::create(
      _["centroids"] = centroids,
      _["centorid_dists"] = centroid_dists,
      _["N"] = N,
      _["Correlations"] = correlations,
      _["AllIters"] = AllIters,
      _["IterIndex"] = iterIndex,
      _["means"] = IterMeans
    );
  } else {
    return List::create(
      _["means"] = IterMeans
    );
  }
}

// [[Rcpp::export]]
List fastLm(const arma::vec & y, const arma::mat & X) {
  int n = X.n_rows, k = X.n_cols;

  arma::colvec coef = arma::solve(X, y);
  arma::colvec resid = y - X*coef;

  double sig2 = arma::as_scalar(arma::trans(resid)*resid/(n-k));

  arma::colvec stderrest = arma::sqrt(sig2 * arma::diagvec( arma::inv(arma::trans(X)*X)) );
  arma::colvec fitted = X * coef;
  bool intercept = false;

  for(int x=0; x<k; x++) {
    if(all(X.col(x) == X(0,x))) intercept = true;
  }

  return List::create(
    Named("coefficients") = coef,
    Named("stderr")       = stderrest,
    Named("residuals")    = resid,
    Named("fitted.values")= fitted,
    Named("intercept")    = intercept
  );
}

// [[Rcpp::export]]
//arma::vec
List summary_fastLm_c(List object) {
  //double se = object["stderr"];
  //tval <- coef(object)/se

  //TAB <- cbind(Estimate = coef(object),
  //         StdErr = se,
  //         t.value = tval,
  //         p.value = 2*pt(-abs(tval), df=object$df))
  //
  //// why do I need this here?
  //rownames(TAB) <- names(object$coefficients)
  //colnames(TAB) <- c("Estimate", "StdErr", "t.value", "p.value")

  // cf src/library/stats/R/lm.R and case with no weights and an intercept

  arma::vec f = object["fitted.values"];
  arma::vec r = object["residuals"];

  //mss <- sum((f - mean(f))^2)
  arma::vec mss;
  if (object["intercept"]){
    mss = sum( pow((f - mean(f) ),2) );
  } else {
    mss = sum(pow(f,2));
  }
  arma::vec rss = sum(pow(r,2));

  arma::vec rSquared = mss/(mss + rss);

  return List::create(
    Named("r.squared") = rSquared(0,0)
  );
}

// [[Rcpp::export]]
List lm_(NumericMatrix x) {
  int chose = x.ncol() * (x.ncol() - 1) / 2;
  NumericVector r_sq(chose); //length=choose(ncol(x), 2));

  uvec C1 = triIndices(x.ncol(), 0);
  uvec C2 = triIndices(x.ncol(), 1);
  for( int n = 0; n < C1.size(); n++ ) {
    NumericVector x1nv = x( _, C1[n] );
    NumericMatrix x1nvMat = NumericMatrix( x1nv.size(), 1 );
    x1nvMat( _, 0) = x1nv;
    NumericVector x2nv = x( _, C2[n] );

    arma::vec x1 = Rcpp::as<arma::vec>(x1nv);
    arma::vec x2 = Rcpp::as<arma::vec>(x2nv);

    Rcpp::List lmList = fastLm( x1, x2 ); //x1nvMat, x2nv );

    r_sq[n] = summary_fastLm_c(lmList)["r.squared"];
  }

  return(List::create(
   _["r.squares"] = r_sq
  ));
}

// :::::::::::::::::::::::::::::::
// :::::: function scale_soln ::::::
// :::::::::::::::::::::::::::::::
//
//   Linearly transform solution to minimize the sum of
//     centroid-projected point distances
//
// parameters
//   xi - solution on dimension i
//   ti - rotated data on dimension i (set$rotated.data[, i])
//   w - adjacency vectors (set$data)
//
//
// returns
//   list.  optim results.  see help(optim)
//

//scale_soln = function(xi, ti, w) {
List scale_soln ( arma::mat xi, arma::mat ti, arma::mat w ) {

  NumericVector rands = runif(2, 1, 1);
  std::vector<double> rands_(2);
  for(int i=0; i < 2; i++) {
    if(i == 0) rands_[i] = -1;
    else rands_[i] = 1;
  }
  //Rcpp::Rcout << "SOLN RANDS: " << rands << std::endl;

  //arma::vec out;
  //Rcpp::Rcout << "XI: " << xi << std::endl;
  //Rcpp::Rcout << "TI: " << ti << std::endl;
  //Rcpp::Rcout << "w: " << w << std::endl;

  SOLN soln = SOLN(w, xi, ti); //, w);
  using BT::Simplex;
  arma::vec sim = Simplex(soln,rands_,1E-3,std::vector<std::vector<double> >());

  //= optim(par = c(1, 1),
  //            fn = obj,
  //            control = list(maxit = 100000,
  //                           reltol=1e-16),
  //            ti = ti,
  //            xi = xi)
  //Rcpp::Rcout << "Soln sim: " << sim << std::endl;

  return(List::create(
    _["out"] = sim,
    _["val"] = soln(sim)
  ));

}

// [[Rcpp::export]]
Rcpp::List full_opt(arma::mat normed, arma::mat rotated, Rcpp::List optim_nodes, int dims = 2, int num_samples = 3) {

  arma::uvec summedMatched = find((sum(normed, 1)) > 0);
  arma::uvec summedMatched_r = find((sum(rotated, 1)));

  arma::mat normedFiltered = normed.rows(summedMatched);
  arma::mat rotatedFiltered = rotated.rows(summedMatched_r);

  arma::mat out = arma::mat(normed.n_rows, normed.n_cols, fill::zeros);

  Rcpp::List nodes = Rcpp::wrap(optim_nodes); //get_optimized_node_pos(normed, rotated, dims, num_samples);
  arma::mat cents = nodes["centroids"];
  //Rcpp::Rcout << "Nodes: " << cents << std::endl;

  int N = Rcpp::as<int>(nodes["N"]);

  arma::fvec sums_sq_dists = arma::fvec(dims);
  arma::mat x_scaled = arma::mat(N, dims);

  NumericMatrix AllIters = Rcpp::as<NumericMatrix>(nodes["AllIters"]);
  NumericMatrix iterIndex = Rcpp::as<NumericMatrix>(nodes["IterIndex"]);
  iterIndex = iterIndex( Range(0, (dims * num_samples) - 1), _ );

  List AllItersList(dims);
  NumericMatrix corrs = nodes["Correlations"];
  for( int i=0; i<dims; i++) {
    NumericVector thisDim = iterIndex( _, 1);
    LogicalVector thisDims = thisDim == i;
    NumericVector thisDimCols = logicalToColNums(thisDims);

    int s=0;
    NumericMatrix AllItersFiltered( AllIters.nrow(), thisDimCols.size());
    for( int j=0; j<thisDimCols.size(); j++) {
      AllItersFiltered( _, s ) = AllIters( _, thisDimCols[j] );
      s++;
    }
    AllItersList[i] = AllItersFiltered;

    List lm_Result = lm_(AllItersFiltered);
    NumericVector rSquares = lm_Result["r.squares"];
    if(min(rSquares) < 0.9) {
      //Rcpp::Rcout << "R squares for dimension "<< i << " indicate ill-conditioned solution: " << rSquares << std::endl;
    }

    //Rcpp::Rcout << "Corrs: " << corrs << std::endl;
    LogicalVector highest_corr_vec = corrs(_, i) == max( corrs(_, i));
    NumericVector thisDimCols2 = logicalToColNums(highest_corr_vec);

    int highest_corr = thisDimCols2(0); // + ((i - 1) * num_samples);

    NumericVector solnV = AllIters( _ , highest_corr);
    arma::vec soln = Rcpp::as<arma::vec>(solnV);
    soln = soln.head( solnV.size() ); // - 2 );
    //Rcpp::Rcout << "SOLN: " << soln << std::endl;

    //Rcpp::Rcout << "rot: " << rotated << std::endl;
    //Rcpp::Rcout << "TI: " << rotatedFiltered.col(i) << std::endl;
    //Rcpp::Rcout << "w: " << normedFiltered << std::endl;

    List scaleResult = scale_soln(soln, rotatedFiltered.col(i), normedFiltered);
    arma::vec scaleVec = scaleResult["out"];
    //Rcpp::Rcout << "SOLN 2: " << scaleVec << std::endl;
    double scaleVal = scaleResult["val"];

    sums_sq_dists[i] = scaleVal;
    arma::vec scaledVec = (scaleVec[0] + (scaleVec[1] * soln));
    x_scaled.col(i) = scaledVec;
  }

  return List::create(
    _["positions"] = x_scaled,
    _["correlations"] = corrs,
    _["sums_sq_dists"] = sums_sq_dists
  );
}

// [[Rcpp::export]]
bool testNO(arma::mat normed, arma::vec rotated, arma::vec soln) {
  float precision = 0.1;
  int dimension = 2;
  NelderMeadOptimizer o(dimension, precision);

  // request a simplex to start with
  Vector2 v(1, 1);
  o.insert(v);
  //o.insert(Vector2(0.1, 0.1));
  //o.insert(Vector2(0.2, 0.7));

  SOLN solnObj = SOLN(normed, soln, rotated);
  Rcpp::Rcout << "SOLN: " << solnObj(v) << std::endl;
  while (!o.done()) {
    v = o.step(v, solnObj(v));
  }
  //Rcpp::Rcout << "V: " << v << std::endl;
  return true;
}

// [[Rcpp::export]]
arma::mat get_cor(arma::vec dists, arma::vec cents) {
  return cor(dists, cents);
}

typedef void (*integrand) (unsigned ndim, const double *x, void *,
              unsigned fdim, double *fval);

// [[Rcpp::export]]
bool run_optimC() {

  return true;
}

// [[Rcpp::export]]
double calc_cor(
  arma::vec x,
  List set,
  int dim
) {
  arma::mat dists = set["rotation_dists"];

  arma::mat t_pair_dists = dists.col(dim);
  arma::mat normed = set["data.normed"];
  double N = getN(normed);
  int K = getK(normed);

  //Rcpp::Rcout << "N: " << N <<std::endl;
  //Rcpp::Rcout << "K: " << K <<std::endl;

  uvec NtriOne = triIndices(N, 0);
  uvec NtriTwo = triIndices(N, 1);
  uvec KtriOne = triIndices(K, 0);
  uvec KtriTwo = triIndices(K, 1);

  arma::mat mps = trans(((x(NtriOne) + x(NtriTwo)) / 2));
  arma::mat multRes = normed * mps.t();
  arma::mat centroids = multRes / sum(normed, 1);
  arma::mat dcentroids = centroids(KtriOne) - centroids(KtriTwo);
  //Rcpp::Rcout << "dcent: " << dcentroids.n_rows << std::endl;
  //Rcpp::Rcout << "dists: " << t_pair_dists.n_rows << std::endl;
  arma::mat c = cor(t_pair_dists, dcentroids, 0);

  //double corrd = c(0,0);
  //Rcpp::Rcout << "Cor: " << c(0,0) << std::endl;
  return c(0,0);
}
