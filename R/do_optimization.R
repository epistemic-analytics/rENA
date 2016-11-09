do_optimization = function(e)
{
  # :::::: load and register doParallel ::::::
  library('doParallel')
  registerDoParallel(cores = detectCores())

  # :::::: function single_optim ::::::
  single_optim = function(e, dim) {
    get_cor = function(x) {
      dim = get("dim", envir = parent.env(environment()))
      t_pair_dists = e$t_pair_dists[, dim]
      mps = (x[e$i] + x[e$j])/2
      centroids = ((e$w %*% as.matrix(mps)) / rowSums(e$w))[,1]
      dcentroids = centroids[e$i2] - centroids[e$j2]
      return(cor(t_pair_dists, dcentroids))
    }

    suppressWarnings(result <- optim(par = runif(e$N,-3, 3),
                                     fn = get_cor,
                                     control = list(fnscale=-1,
                                                    maxit=e$maxit),
                                     lower=-3,
                                     upper=3))
    #browser();
    out = c(result$par, result$value, dim)
    #names(out) = c(e$node_names, "corr", "dim")
    return(out)
  }

  # :::::: execute in parallel ::::::
  optimization_results=
    foreach(dim=1:e$num_dims, .combine=cbind) %:%
    foreach(i_sample=1:e$num_samples, .combine=cbind) %do% {
      single_optim(e, dim)
    }

  print(optimization_results);
  optimization_results_2 = matrix()

  return(optimization_results)
}
