# This needs to take the full list for defaltion, not just a single
# grouping

ena.rotate.by.mean = function(data, groups) {


#ena.rotate.by.mean = function(data, col, vals) {
  attrData = attr(data, UNIT_NAMES)

  data = scale(data, scale=F, center=T);

  col = NULL;
  vals = NULL;

  deflated.data = data;
  i = 1;
  weights = matrix(0, nrow = ncol(deflated.data), ncol = length(groups));

  for(group in names(groups)) {
    col = group;
    vals = groups[[group]];

    colOne.rows = as.logical(attrData[, c(col), with=F] == vals[1]);
    colTwo.rows = as.logical(attrData[, c(col), with=F] == vals[2]);
    colOne.vals = deflated.data[colOne.rows,]
    colTwo.vals = deflated.data[colTwo.rows,]
    colOne.means = colMeans(colOne.vals)
    colTwo.means = colMeans(colTwo.vals)
    col.mean.diff = colOne.means - colTwo.means

    col.mean.diff.sq = col.mean.diff/sqrt(sum(col.mean.diff^2))

    deflated.data = deflated.data - (deflated.data %*% col.mean.diff.sq) %*% t(col.mean.diff.sq)

    #col.mean.diff.sq = as.matrix(col.mean.diff.sq);
    weights[,i] = col.mean.diff.sq;
    i = i + 1;
  }
  deflated.data.svd = orthogonal.svd(deflated.data, weights); #col.mean.diff.sq);

  colnames(deflated.data.svd) = c(
     paste('V',as.character(1:ncol(deflated.data.svd)), sep='')
  );


  return(deflated.data.svd[,1:2]);
}

orthogonal.svd = function(data, weights) {
  if(class(data) != "matrix"){
    message("orthogonalSVD:  converting data to matrix")
    data = as.matrix(data)
  }
  #Find the orthogonal transformation that includes W
  Q = qrOrtho(weights)
  X.bar = data%*%Q[,(ncol(weights)+1):ncol(Q)]
  V = prcomp(X.bar, scale.=F)$rotation
  if (class(V)=="numeric") {
    V = matrix(V,nrow=length(V))
  }

  toReturn = (cbind(Q[,1:ncol(weights)], Q[,(ncol(weights)+1):ncol(Q)]%*%V));
  #print(colnames(toReturn))
  return(toReturn);
}

qrOrtho = function(A) {
  return(qr.Q(qr(A),complete=T))
}
