maxit = 1000
e = gotSet;
e_ = e;

if(is(e, "ENAset")) {
  e_list = list(
    data.normed = e$data$normed.non.zero,
    rotation_dists = e$rotation_dists,
    dims = e$get("dimensions"),
    samples = e$get("samples"),
    N = e$get("N"),
    n1 = e$get("n1"),
    n2 = e$get("n2"),
    K = e$get("K"),
    k1 = e$get("k1"),
    k2 = e$get("k2")
  );

  e = e_list;
}

single_optim = function(e, dim) {
  library(gsl);
  get_cor = function(x) {
    dim = get("dim", envir = parent.env(environment()))
    t_pair_dists = e$rotation_dists[, dim]
    mps = (x[e$n1] + x[e$n2])/2
    centroids = ((e$data.normed %*% as.matrix(mps)) / rowSums(e$data.normed))[,1]
    dcentroids = centroids[e$k1] - centroids[e$k2]
    return(cor(t_pair_dists, dcentroids))
  }
  set.seed(42);
  # suppressWarnings(result <- optim(par = runif(e$N,-3, 3),
  #                                  fn = get_cor,
  #                                  control = list(fnscale=-1,
  #                                                 maxit=maxit),
  #                                  lower=-3,
  #                                  upper=3))
  # out = c(result$par, result$value, dim)

  gsl::multimin(x=runif(e$N,-3, 3), f=get_cor, method="nm")

  }

opted = single_optim(e, 1)
