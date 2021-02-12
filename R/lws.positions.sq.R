# Ellipsoidal scaling version
lws.positions.sq <- function(enaset) {
  points = as.matrix(enaset$points)
  weights = as.matrix(enaset$line.weights)
  positions = lws_lsq_positions(weights, points, ncol(points));

  node.positions = positions$nodes;
  rownames(node.positions) = enaset$enadata$codes;

  return(list("node.positions" = node.positions, "centroids" = positions$centroids))
}

lws.positions.sq.R6 <- function(enaset) {
  if( enaset$center.align.to.origin)
  {
    positions = lws_lsq_positions(enaset$line.weights[rowSums(as.matrix(enaset$line.weights))!=0,], enaset$points.rotated[rowSums(as.matrix(enaset$points.rotated))!=0,], enaset$get("dimensions"));
    mean_centroids = colMeans(positions$centroids);
    centroids = enaset$points.rotated;
    centroids[rowSums(as.matrix(centroids))!=0,] = t(t(positions$centroids)-mean_centroids)
    positions$centroids = centroids;
    positions$nodes = t(t(positions$nodes)-mean_centroids)
  }
  else
  {
    positions = lws_lsq_positions(enaset$line.weights, enaset$points.rotated, enaset$get("dimensions"));
  }

  node.positions = positions$nodes;
  rownames(node.positions) = enaset$enadata$codes;

  return(list("node.positions" = node.positions, "centroids" = positions$centroids))

}
