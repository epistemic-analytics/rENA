library('doParallel')


do_opt = function(
  num_dims, num_samples,
  t_pair_dists, normed
) {
  N = getN(normed);
  K = getK(normed);
  nTriOne = triIndices(N, 0);
  nTriTwo = triIndices(N, 1);
  kTriOne = triIndices(K, 0);
  kTriTwo = triIndices(K, 1);

  # :::::: function single_optim ::::::
  single_optim = function(dim) {
    get_cor = function(x, t_pair_dists, normed, nTriOne, nTriTwo, kTriOne, kTriTwo) {
      dim = get("dim", envir = parent.env(environment()))
      t_pair_dists_dim = t_pair_dists[, dim];
      mps = (x[nTriOne] + x[nTriTwo])/2;
      centroids = ((normed %*% as.matrix(mps)) / rowSums(normed))[,1];
      dcentroids = centroids[kTriOne] - centroids[kTriTwo];
      return(cor(t_pair_dists_dim, dcentroids))
    }

    suppressWarnings(result <- optim(
      par = runif(N,-3, 3),
      fn = get_cor,
      gr = NULL,
      control = list(fnscale=-1, maxit=1000),
      lower=-3,
      upper=3,
      t_pair_dists, normed, nTriOne, nTriTwo, kTriOne, kTriTwo
    ));

    out = c(result$par, result$value, dim)
    #names(out) = c(e$node_names, "corr", "dim")

    return(out)
  }

  # :::::: execute in parallel ::::::
  optimization_results=
    foreach(dim=1:num_dims, .combine=cbind) %:%
    foreach(i_sample=1:num_samples, .combine=cbind) %do% {
      single_optim(dim)
    }

  # ::::::: execute normally :::::::
  #i = 1
  #optimization_results=matrix(0, nrow=(N+2), ncol=(num_dims*num_samples))
  #for(dim in 1:num_dims) {
  #  for(i_sample in 1:num_samples) {
  #    optimization_results[, i] = single_optim(dim);
  #    i=i+1;
  #  }
  #}
  return(optimization_results)
}
