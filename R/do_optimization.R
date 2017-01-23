do_optimization = function(e, inPar = F, maxit = 1000)
{
  # :::::: load and register doParallel ::::::
  library('doParallel')
  registerDoParallel(cores = detectCores())

  # :::::: function single_optim ::::::
  single_optim = function(e, dim) {
    get_cor = function(x) {
      dim = get("dim", envir = parent.env(environment()))
      t_pair_dists = e$rotation_dists[, dim]
      mps = (x[e$i] + x[e$j])/2
      centroids = ((e$data.normed %*% as.matrix(mps)) / rowSums(e$data.normed))[,1]
      dcentroids = centroids[e$i2] - centroids[e$j2]
      return(cor(t_pair_dists, dcentroids))
    }
    set.seed(42);
    suppressWarnings(result <- optim(par = runif(e$N,-3, 3),
                                     fn = get_cor,
                                     control = list(fnscale=-1,
                                                    maxit=maxit),
                                     lower=-3,
                                     upper=3))
    out = c(result$par, result$value, dim)
    #names(out) = c(e$node_names, "corr", "dim")
    return(out)
  }

  #if(is.null(e$N)){
    e$N = getN(e$data.normed);
    e$K = getK(e$data.normed);
    e$i = which(upper.tri(diag(e$N)), arr.ind = T)[, 1]
    e$j = which(upper.tri(diag(e$N)), arr.ind = T)[, 2]
    e$i2 = which(upper.tri(diag(e$K)), arr.ind = T)[, 1]
    e$j2 = which(upper.tri(diag(e$K)), arr.ind = T)[, 2]
  #}

  if(inPar == T) {
    # :::::: execute in parallel ::::::
    optimization_results=
      foreach(dim=1:e$dims, .combine=cbind) %:%
      foreach(i_sample=1:e$samples, .combine=cbind) %do% {
        single_optim(e, dim)
      }
  } else {
    optimization_results=matrix(0, nrow=(getN(e$data.normed)+2), ncol=e$dims*e$samples);
    col = 1;
    for(dim in 1:e$dims) {
      for(i_sample in 1:e$samples) {
        optimization_results[,col] = single_optim(e, dim);
        col = col + 1;
      }
    }
  }
  return(optimization_results)
}

do_optimization_2 = function(e, inPar=F, maxit = 1000) {
  e_ = e;

  if(is(e, "ENAset")) {
    e_list = list(
      data.normed = e$data$normed.non.zero,
      rotation_dists = e$rotation_dists,
      dims = e$get("dimensions"),
      samples = e$get("samples")
    );

    e = e_list;
  }
  # :::::: function single_optim ::::::
  limits=list(min=-3,max=3);

  single_optim = function(e, dim, N = getN(e$data.normed)) {
    #browser();
    set.seed(42)
    result <- suppressWarnings(optim(par = runif(N,limits$min, limits$max),
                                     fn = calc_cor,
                                     gr = NULL,
                                     e, dim-1, # ... parameters to calc_cor()
                                     method = "Nelder-Mead",
                                     control = list(
                                       fnscale=-1,maxit=1000
                                     )
                                     ,lower=limits$min, upper=limits$max))
    out = c(result$par, result$value, dim)
    #names(out) = c(e$node_names, "corr", "dim")
    return(out)
  }

  #browser()
  N = getN(e$data.normed);
  if(inPar == T) {
    # :::::: load and register doParallel ::::::
    library('doParallel')
    registerDoParallel(cores = detectCores())

    # :::::: execute in parallel ::::::
    optimization_results=
      foreach(dim=1:e$dims, .combine=cbind) %:%
      foreach(i_sample=1:e$samples, .combine=cbind) %do% {
        single_optim(e, dim, N)
      }
  } else {
    optimization_results=matrix(0, nrow=(N+2), ncol=e$dims*e$samples);
    col = 1;
    for(dim in 1:e$dims) {
      for(i_sample in 1:e$samples) {
        optimization_results[,col] = single_optim(e, dim, N);
        col = col + 1;
      }
    }
  }

  #browser()
  return(optimization_results)
}
