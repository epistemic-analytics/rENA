Rcpp::sourceCpp(code='
  // [[Rcpp::depends(RcppArmadillo)]]

  #include <iostream>
  #include <vector>
  #include <ctime>
  #include <algorithm>
  #include <iterator>
  #include <cmath>
  #include <RcppArmadillo.h>
  #include "/Users/clmarquart/Workspaces/RStudio2/rENA/src/simplex.h"

  using namespace Rcpp;
  using namespace arma;
  using namespace std;

  template<class Con>
  void printcon(const Con& c){
    //std::cout.precision(12);
    copy(c.begin(),c.end(),ostream_iterator<typename Con::value_type>(Rcpp::Rcout, "  "));
    Rcpp::Rcout << "HERE: " << std::endl;
  }
  int count_if(LogicalVector x) {
    int counter = 0;
    for(int i = 0; i < x.size(); i++) {
      if(x[i] == TRUE) {
        counter++;
      }
    }
    return counter;
  }
  int vecmin(NumericVector x) {
    // Rcpp supports STL-style iterators
    NumericVector::iterator it = std::min_element(x.begin(), x.end());
    // we want the value so dereference
    return *it;
  }
  int vecmax(NumericVector x) {
    // Rcpp supports STL-style iterators
    NumericVector::iterator it = std::max_element(x.begin(), x.end());
    // we want the value so dereference
    return *it;
  }
  NumericVector logicalToColNums( LogicalVector lv ) {
    int size = lv.size();
    NumericVector nv(count_if(lv));
    //Rcpp::Rcout << "Total: " << lv << std::endl << count_if(lv) << std::endl;

    int s=0;
    for ( int i=0; i<size; i++) {
      //Rcpp::Rcout << "Size: " << lv[i] << std::endl;
      if(lv[i] == 1) {
        nv(s) = i;
        s++;
      }
    }

    return nv;
  }

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
          int dim
        ) : dists(dists),
            normed(normed),
            NtriOne(NtriOne),
            NtriTwo(NtriTwo),
            KtriOne(KtriOne),
            KtriTwo(KtriTwo),
            dim(dim) {}


        //arma::mat
        double operator()(vector<double> x){
          return this->calc( arma::vec(x) );
          //return 2.0; //100*pow(x[1]-pow(x[0],2),2)+pow(1-x[0],2);
        }

        double calc(arma::vec x) {
          arma::mat t_pair_dists = this->dists.col(this->dim);
          arma::mat mps = ((x(this->NtriOne) + x(this->NtriTwo)) / 2);
          arma::mat centroids = ((sum(this->normed, 0) % trans(mps)) - sum(this->normed, 0));
          arma::mat dcentroids = centroids(this->KtriOne) - centroids(this->KtriTwo);

          arma::mat c = cor(t_pair_dists, dcentroids);

          return(c(0,0));
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

  Rcpp::List fastLm(NumericMatrix Xr, NumericVector yr) {
    //try {
      //Rcpp::NumericVector yr(ys);                     // creates Rcpp vector from SEXP
      //Rcpp::NumericMatrix Xr(Xs);                     // creates Rcpp matrix from SEXP
      int n = Xr.nrow(), k = Xr.ncol();
      arma::mat X(Xr.begin(), n, k, false);           // reuses memory and avoids extra copy
      arma::colvec y(yr.begin(), yr.size(), false);

      arma::colvec coef = arma::solve(X, y);      	// fit model y ~ X
      arma::colvec res  = y - X*coef;			// residuals

      double s2 = std::inner_product(res.begin(), res.end(), res.begin(), 0.0)/(n - k);
      // std.errors of coefficients
      arma::colvec std_err = arma::sqrt(s2 * arma::diagvec( arma::pinv(arma::trans(X)*X) ));

      return Rcpp::List::create(
        Rcpp::Named("coefficients") = coef,
        Rcpp::Named("stderr")       = std_err, //Rcpp::as<NumericVector>(std_err),
        Rcpp::Named("df.residual")  = n - k
      );
    //} catch( std::exception &ex ) {
    //    forward_exception_to_r( ex );
    //} catch(...) {
    //  ::Rf_error( "c++ exception (unknown reason)" );
    //}

    return R_NilValue; // -Wall
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
  Rcpp::NumericMatrix rotate_c(DataFrame df){
    int dfRows = df.nrows();
    int dfCols = df.size();
    arma::mat m(dfRows, dfCols, fill::zeros);
    for (int i=0; i<dfCols;i++) {
      m.col(i) = Rcpp::as<arma::vec>(df[i]);
    }
    //m = trans(m);

    arma::mat pca = arma::princomp(m); //, retx=FALSE,scale=FALSE,center=FALSE, tol=0)

    //colnames(n$rotation) <- sub("PC", "svd ", colnames(n$rotation))
    //n$eigenvalues=n$sdev^2
    //n$percent=n$eigenvalues/sum(n$eigenvalues)
    //dimensions = 1:6
    //dimensions = dimensions[!(dimensions > ncol(n$rotation))]
    //n$rotation = n$rotation[, dimensions]
    //n$eigenvalues=n$eigenvalues[dimensions]
    //n$percents=n$percents[dimensions]
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
    //Rcpp::Rcout << rotatedCentered << std::endl;
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

  vec single_optim(
    arma::mat normed, arma::mat dists,
    arma::mat rotated,
    arma::uvec NtriOne, arma::uvec NtriTwo,
    arma::uvec KtriOne, arma::uvec KtriTwo,
    int dim = 0, double N = 0.0
  ) {

    CorENA co = CorENA(
      dists,
      normed,
      NtriOne,
      NtriTwo,
      KtriOne,
      KtriTwo,
      dim
    );

    NumericVector rands = runif(N, -3, 3);

    std::vector<double> rands_(N);

    NumericVector::iterator it;
    for(it = rands.begin(); it != rands.end(); it++) {
      rands_.push_back(*it);
    }

    using BT::Simplex;
    vec sim = Simplex(
      co,
      rands_
      ,1E-1 //1E8*std::numeric_limits<double>::epsilon()
      ,std::vector<std::vector<double> >()
      //,1E5
    );
    //Rcpp::Rcout << "Sim: " << sim << std::endl;
    return sim;
  }

  NumericMatrix do_opt(
    arma::mat normed,
    arma::mat dists,
    arma::mat rotated,
    arma::uvec NtriOne, arma::uvec NtriTwo,
    arma::uvec KtriOne, arma::uvec KtriTwo,
    double N = 1.0, int num_samples = 100
  ) {
    NumericMatrix soRes(N*num_samples, N*2+2); //, N);
    //Rcpp::Rcout << "SO RES: " << std::endl << IntegerMatrix(soRes) << std::endl;

    //Rcpp::Rcout << "N: " << N << std::endl;
    //Rcpp::Rcout << "Samps: " << num_samples << std::endl;

    int r = 0;
    for(int i=0; i<N; i++) {

      for(int j=0; j<num_samples; j++) {
        int s = 0;
        //Rcpp::Rcout << "Row: " << r << " -> Running dim: " << i << " , " << " sample: " << j << std::endl;

        vec nV = single_optim(normed, dists, rotated, NtriOne, NtriTwo, KtriOne, KtriTwo, i, N);
        NumericVector newVec = wrap(nV);

        //Rcpp::Rcout << "NV: " << newVec << std::endl << std::endl;
        for(int k=0; k < N*2; k++) {
          soRes(r, s) = nV[k]; //newVec;
          s++;
        }

        soRes(r, s) = 1.0; // FIXME: this should be a correlation value?

        s = s + 1;
        soRes(r, s) = i;
        r++;
      }
    }

    return soRes;
  }

  // [[Rcpp::export]]
  Rcpp::List get_optimized_node_pos(
      arma::mat normedFiltered,
      arma::mat rotatedFiltered,
      int num_dims=2, int num_samples=3, int max_iter=1000,
      bool return_all = true
  ) {
    arma::uvec b = find(any(normedFiltered != 0, 1) > 0); //apply(normed, 1, function(z) !all(z==0))
    arma::mat normedNonZero = normedFiltered.rows(b);

    int K = normedNonZero.n_rows;
    double N = 0.5 + sqrt( 0.25 + 2*normedNonZero.n_cols );

    uvec NtriOne = triIndices(N, 0);
    uvec NtriTwo = triIndices(N, 1);
    uvec KtriOne = triIndices(K, 0);
    uvec KtriTwo = triIndices(K, 1);

    arma::mat pairDists = (rotatedFiltered.rows(KtriOne) - rotatedFiltered.rows(KtriTwo));

    NumericMatrix opted = do_opt(normedFiltered, pairDists, rotatedFiltered, NtriOne, NtriTwo, KtriOne, KtriTwo, N, num_samples);

    NumericMatrix optedRes = opted( _ , Range(4,9) );
    optedRes = transpose(optedRes);

    CharacterVector pc_names(num_dims);
    for(int i=0; i<num_dims; i++) {
      pc_names[i] = "PC" + std::to_string(i);
    }
    opted.attr("colnames") = pc_names;

    NumericVector correlations = optedRes( optedRes.nrow() - 2, _ );

    CharacterVector iterNames(optedRes.ncol());
    NumericMatrix iterIndex(N * num_samples, 2);
    for(int i=0; i<optedRes.ncol(); i++) {
      iterNames[i] = "PC_" + std::to_string((int) optedRes(optedRes.nrow() - 1, i)) + "_iter_"+ std::to_string((int) i);
      iterIndex(i, 0) = optedRes(optedRes.nrow() - 2, i);
      iterIndex(i, 1) = optedRes(optedRes.nrow() - 1, i);
    }

    arma::mat AllIters = Rcpp::as<arma::mat>(optedRes);
    arma::mat IterMeans = arma::mat(N, num_dims, fill::zeros);
    NumericVector dimRow = optedRes( optedRes.nrow() - 1, _ );

    int t=0;
    for( int i=0; i<num_dims; i++) {
      LogicalVector dimRowFilter = ( dimRow == 0 );

      int s=0;
      NumericMatrix rowsToSum( optedRes.nrow()-2, num_samples );
      for ( int j=0; j<dimRowFilter.size(); j++) {
        if( dimRowFilter[j] == true) {
          rowsToSum( _, s ) = optedRes( _, j );
        }
        s++;
      }
      arma::vec rowsMeaned = mean(Rcpp::as<arma::mat>(rowsToSum), 1);

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

    arma::mat centroid_dists = centroids.cols(KtriOne) - centroids.cols(KtriTwo);

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

  Rcpp::NumericVector lm_(NumericMatrix x) {
    Environment stats("package:stats");
    Function summary = stats["summary.lm"];

    Environment base("package:base");
    Function choose = base["choose"];

    int chose = Rcpp::as<int>(choose(x.ncol(), 2));
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

      Rcpp::List lmList = fastLm( x1nvMat, x2nv );
      arma::colvec coef = lmList["coefficients"];

      //Rcpp::Rcout << "Coef: " << coef[0] << std::endl;
      r_sq[n] = coef[0]; //summary(lm(x[, i] ~ x[, j]))$r.squared
    }
    //Rcpp::Rcout << "R_sq: " << r_sq << std::endl;

    return(r_sq);
  }

  // [[Rcpp::export]]
  Rcpp::List full_opt(arma::mat normed, arma::mat rotated, int dims = 2) {
    //, IntegerVector dims = IntegerVector::create(2, Range(0,1)) ) {
    arma::mat out = arma::mat(normed.n_rows, normed.n_cols, fill::zeros);
    arma::vec summed = sum(normed, 1);
    arma::uvec summedMatched = find(summed > 0);

    arma::mat normedFiltered = normed.rows(summedMatched);
    arma::mat rotatedFiltered = rotated.rows(summedMatched);
    Rcpp::List nodes = get_optimized_node_pos(normedFiltered, rotated, dims);
    int N = Rcpp::as<int>(nodes["N"]);
    arma::fvec sums_sq_dists = arma::fvec(dims);
    arma::fmat x_scaled = arma::fmat(N, dims);

    NumericMatrix AllIters = Rcpp::as<NumericMatrix>(nodes["AllIters"]);
    NumericMatrix iterIndex = Rcpp::as<NumericMatrix>(nodes["IterIndex"]);
    List AllItersList(dims);

    for( int i=0; i<dims; i++) {
      //r_sq = lm_(x$x_all_iters[, x$iter_index[, 2] == dim])
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

      NumericVector rSquares = lm_(AllItersFiltered);
      if(min(rSquares) < 0.9) {
        Rcpp::Rcout << "R squares for dimenstion "<< i << " indicate ill-conditioned solution: " << rSquares << std::endl;
      }

      //find the max correlations
    }

    return AllItersList;
  }
');

library(RcppArmadillo)
#print(normIt(1));
#normed = normIt(apply(as.matrix(newRes)[,2:ncol(newRes)], 2, as.numeric));
normed = normIt(apply(as.matrix(newRes)[,2:7], 2, as.numeric));
rotatedC = rotate_c(normed)
centeredData = centerData(rotatedC);
centeredDataRotated = centerDataRotated(centeredData, rotatedC)
#print(eq_pos(codeNames, make.adjacency.labels(codeNames), as.matrix(rotatedC), T))
opt_nodes = full_opt(normed=normed, rotated=centeredDataRotated, 3) #, )$x_scaled[, dimensions];
