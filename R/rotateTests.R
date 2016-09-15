Rcpp::sourceCpp(code='
  // [[Rcpp::depends(RcppArmadillo)]]


  #include <RcppArmadillo.h>
  #include "/Users/clmarquart/Workspaces/RStudio2/rENA/src/simplex.h"


  using namespace Rcpp;
  using namespace arma;

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

    //Rcpp::Rcout << pca << std::endl; // << score << std::endl;
    //Rcpp::Rcout << latent << std::endl << tsquared << std::endl;

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

  int getcor(
    arma::mat dists, arma::mat normed, arma::mat x,
    arma::uvec NtriOne, arma::uvec NtriTwo,
    arma::uvec KtriOne, arma::uvec KtriTwo,
    int dim = 0
  ) {
    arma::mat t_pair_dists = dists.col(dim);
    arma::mat mps = ((x(NtriOne) + x(NtriTwo)) / 2);
    arma::mat centroids = ((sum(normed, 0) % trans(mps)) - sum(normed, 0));
    arma::mat dcentroids = centroids(KtriOne); // - centroids(KtriTwo);

    return(cor(t_pair_dists, dcentroids))
  }

  int single_optim(
    arma::mat normed, arma::mat dists,
    arma::mat rotated,
    arma::uvec NtriOne, arma::uvec NtriTwo,
    arma::uvec KtriOne, arma::uvec KtriTwo,
    int dim = 0, double N = 0.0
  ) { //, arma::mat rotated) {
    Rcpp::Rcout << "Dim: " << normed << std::endl;
    //optim(par = runif(N,-3, 3),
    //      fn = get_cor,
    //      control = list(fnscale=-1,
    //      maxit=e$maxit),
    //      lower=-3, upper=3);
    //out = c(result$par, result$value, dim);
    //names(out) = c(e$node_names, "corr", "dim");
    //return(out);

    vec v = randn<vec>(10); //, distr_param(2,1));

    getcor(dists, normed, runif(N, -3, 3), NtriOne, NtriTwo, KtriOne, KtriTwo, dim);

    //Rcpp::Rcout << "HERE:" << Simplex(normed, rotated.row(0)) << std::endl;
    return 2;
  }

  int do_opt(
    arma::mat normed, arma::mat dists,
    arma::mat rotated,
    arma::uvec NtriOne, arma::uvec NtriTwo,
    arma::uvec KtriOne, arma::uvec KtriTwo,
    double N = 0.0
  ) {
    single_optim(normed, dists, rotated, NtriOne, NtriTwo, KtriOne, KtriTwo, 0, N);
    return 3;
  }

  // [[Rcpp::export]]
  double get_optimized_node_pos(
      arma::mat normedFiltered,
      arma::mat rotatedFiltered,
      int num_samples=3, int num_dims=2, int max_iter=1000
  ) {
    //Rcpp::Rcout << "HERE:" << normedFiltered << std::endl;
    //Rcpp::Rcout << find(any(normedFiltered != 0, 1) > 0) << std::endl;
    arma::uvec b = find(any(normedFiltered != 0, 1) > 0); //apply(normed, 1, function(z) !all(z==0))
    //Rcpp::Rcout << "B: " << std::endl << b << std::endl;

    arma::mat normedNonZero = normedFiltered.rows(b);

    int K = normedNonZero.n_rows;
    double N = 0.5 + sqrt( 0.25 + 2*normedNonZero.n_cols );

    Rcpp::Rcout << "K: " << K << std::endl;
    Rcpp::Rcout << "N: " << N << std::endl;
    //Rcpp::Rcout << "Non: " << normedFiltered << std::endl;

    uvec NtriOne = triIndices(N, 0);
    uvec NtriTwo = triIndices(N, 1);
    uvec KtriOne = triIndices(K, 0);
    uvec KtriTwo = triIndices(K, 1);

    //arma::mat rotatedFilteredTop = rotatedFiltered.rows(Ntri.row(0));
    //arma::mat f = rotatedFiltered.col(0);

    //Rcpp::Rcout << rotatedFiltered.rows(KtriOne) << std::endl;
    //Rcpp::Rcout << rotatedFiltered.rows(KtriTwo) << std::endl;

    arma::mat pairDists = (rotatedFiltered.rows(KtriOne) - rotatedFiltered.rows(KtriTwo));

    do_opt(normedFiltered, pairDists, rotatedFiltered, NtriOne, NtriTwo, KtriOne, KtriTwo, N);

    return N;

    //e$t_pair_dists = t[e$i2, ] - t[e$j2, ]
    //
    //# :::::: Execute all ::::::
    //y = do_optimization(e)
    //
    //# :::::: Parse results ::::::
    //pc_names = sapply(1:num_dims, function(z) paste(c("PC", z), collapse=""))
    //
    //e$correlations = matrix(y[nrow(y)-1, ],
    //nrow=e$num_samples, ncol=num_dims,
    //dimnames=list(NULL, pc_names))
    //
    //e$iter_names = vector(length=ncol(y))
    //e$iter_index = matrix(nrow=e$num_samples*e$num_dims, ncol = 2, dimnames=list(NULL, c("iter", "dim")))
    //for(i in 1:ncol(y)){
    //  e$iter_names[i] = paste(c("PC_", y[nrow(y), i], "_iter_", i), collapse="")
    //  e$iter_index[i, 1] = y[nrow(y)-1, i]
    //  e$iter_index[i, 2] = y[nrow(y), i]
    //}
//
    //e$x_all_iters = matrix(y[1:(nrow(y)-2), ], nrow=e$N, ncol=num_dims*e$num_samples, dimnames=list(e$node_names, e$iter_names))
    //e$x = matrix(nrow=e$N, ncol=num_dims, dimnames=list(e$node_names, pc_names))
//
    //for(i in 1:num_dims) {
    //  e$x[, i] = rowMeans(y[1:(nrow(y)-2), y[nrow(y), ]==i])
    //}
    //
    //# :::::: compute centroids and their paired distances ::::::
    //e$centroids = matrix(nrow=e$K, ncol=ncol(e$x_all_iters))
    //for(i in 1:ncol(e$centroids)) {
    //  mps = (e$x_all_iters[e$i, i] + e$x_all_iters[e$j, i])/2
    //  e$centroids[, i] = apply(e$w, 1, function(z) sum(z*mps)/sum(z))
    //}
    //
    //e$cen_pair_dists = e$centroids[e$i2, ] - e$centroids[e$j2, ]
    //
    //if(return_all) {
    //  e$opt_params = list(max_iterations = e$maxit,
    //  n_samples = e$num_samples,
    //  num_dims = e$num_dims)
    //  e$list_names = names(e)
//
    //  for(i in c("maxit", "num_samples", "i", "j", "i2", "j2"))
    //    e[[i]] = NULL
//
    //  return(e)
    //}
    //
    //if(!return_all) return(e$x)
  }

  // [[Rcpp::export]]
  Rcpp::NumericMatrix full_opt(arma::mat normed, arma::mat rotated) {
    //, IntegerVector dims = IntegerVector::create(2, Range(0,1)) ) {
    arma::mat out = arma::mat(normed.n_rows, normed.n_cols, fill::zeros);
    arma::vec summed = sum(normed, 1);
    arma::uvec summedMatched = find(summed > 0);

    //Rcpp::Rcout << std::endl << rotated << std::endl;

    arma::mat normedFiltered = normed.rows(summedMatched);
    arma::mat rotatedFiltered = rotated.rows(summedMatched);

    Rcpp::Rcout << normedFiltered << std::endl << rotatedFiltered << std::endl;

    int r = get_optimized_node_pos(normedFiltered, rotated);
    //Rcpp::Rcout << "R:" << r << std::endl;
    return Rcpp::wrap(out);
  }
');

#print(normIt(1));
normed = normIt(apply(as.matrix(newRes)[,2:7], 2, as.numeric));
rotatedC = rotate_c(normed)
centeredData = centerData(rotatedC);
centeredDataRotated = centerDataRotated(centeredData, rotatedC)
#print(eq_pos(codeNames, make.adjacency.labels(codeNames), as.matrix(rotatedC), T))
full_opt(normed=normed, rotated=centeredDataRotated) #, )$x_scaled[, dimensions];

