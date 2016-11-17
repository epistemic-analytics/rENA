library(nloptr);
library(subplex);

get_cor = function(x, e, dim, N=NULL, K=NULL, i=NULL,j=NULL,i2=NULL,j2=NULL) {
  if(is.null(N)) {
    N = getN(e$data.normed);
    K = getK(e$data.normed);
    i = triIndices(N, 0);
    j = triIndices(N, 1);
    i2 = triIndices(K, 0);
    j2 = triIndices(K, 1);
  }

  t_pair_dists = e$rotation_dists[, dim]
  mps = (x[i] + x[j])/2
  centroids = ((e$data.normed %*% as.matrix(mps)) / rowSums(e$data.normed))[,1]

  dcentroids = centroids[i2] - centroids[j2]
  corr = cor(t_pair_dists, dcentroids)

  return(corr)
}
N = getN(enaset$data.normed);
K = getK(enaset$data.normed);
i = triIndices(N, 0);
j = triIndices(N, 1);
i2 = triIndices(K, 0);
j2 = triIndices(K, 1);

ctrls = list(maxeval=1000,xtol_rel= -1);
ctrls2= list(fnscale=-1,maxit=1000);
print(microbenchmark(
  #subplex(runif(6,-3,3), fn=get_cor, control=list(reltol=1e-10), hessian=F, enaset, 1),
  #subplex(runif(6,-3,3), fn=get_cor, control=list(reltol=1e-10), hessian=F, enaset, 1,N,K,i,j,i2,j2),
  #subplex(runif(6,-3,3), fn=calc_cor, control=list(reltol=1e-10), hessian=F, enaset, 1),
  #neldermead(runif(6,-3,3), fn = get_cor, lower = rep(-3, 6), upper=rep(3,6), nl.info = F, control=ctrls , enaset, 1),
  #neldermead(runif(6,-3,3), fn = get_cor, lower = rep(-3, 6), upper=rep(3,6), nl.info = F, control=ctrls , enaset, 1,N,K,i,j,i2,j2),
  #neldermead(runif(6,-3,3), fn = calc_cor, lower = rep(-3, 6), upper=rep(3,6), nl.info = F, control=ctrls , enaset, 1),
  #sbplx(runif(6,-3,3), fn = get_cor, lower = rep(-3, 6), upper=rep(3,6), nl.info = F, control=ctrls, enaset, 1),
  #sbplx(runif(6,-3,3), fn = get_cor, lower = rep(-3, 6), upper=rep(3,6), nl.info = F, control=ctrls, enaset, 1,N,K,i,j,i2,j2),
  #sbplx(runif(6,-3,3), fn = calc_cor, lower = rep(-3, 6), upper=rep(3,6), nl.info = F, control=ctrls, enaset, 1),
  suppressWarnings(optim(par=runif(4,-3,3), fn=get_cor, gr=NULL, enaset, 1,N,K,i,j,i2,j2, method="Nelder-Mead", lower = -3, upper = 3, control=ctrls2)),
  suppressWarnings(optim(par=runif(4,-3,3), fn=get_cor, gr=NULL, enaset, 1, method="Nelder-Mead", lower = -3, upper = 3, control=ctrls2)),
  suppressWarnings(optim(par=runif(4,-3,3), fn=calc_cor, gr=NULL, enaset, 1, method="Nelder-Mead", lower = -3, upper = 3, control=ctrls2))
#  ,times = 1000
))
