ena.rotate.by.mean = function(set, col, vals) {
  browser()

  attrData = attr(set$data$normed, UNIT_NAMES)

  colOne.rows = as.logical(attrData[, c(col), with=F] == vals[1]);
  colTwo.rows = as.logical(attrData[, c(col), with=F] == vals[2]);
  colOne.vals = set$data$normed[colOne.rows,]
  colTwo.vals = set$data$normed[colTwo.rows,]
  colOne.means = colMeans(colOne.vals)
  colTwo.means = colMeans(colTwo.vals)
  col.mean.diff = colOne.means - colTwo.means
  col.mean.diff.sq = col.mean.diff/sqrt(sum(col.mean.diff^2))

  deflated.data = set$data$normed - (set$data$normed %*% col.mean.diff.sq) %*% t(col.mean.diff.sq)

  return(deflated.data);
}
