ena.set <- function(x) {
  newset = list(
    connection.matrices = NULL,
    connection.counts = x$points.raw,
    line.weights = x$line.weights,
    meta.data = x$enadata$raw,
    model = list(
      model.type = x$enadata$model,
      centroids = x$centroids,
      correlations = x$correlations,
      points.for.projection = x$points.normed.centered,
      variance = x$variance,
      function.call = x$function.call,
      function.params = x$function.params,
      row.connection.counts = x$enadata$accumulated.adjacency.vectors,
      unit.labels = x$enadata$unit.names
    ),
    points = x$points.rotated,
    rotation.matrix = x$rotation.set$rotation,
    trajectories = x$enadata$trajectories$step,
    units = x$enadata$units,
    rotation = list(
      eigenvalues = x$rotation.set$eigenvalues,
      rotation.matrix = x$rotation.set$rotation,
      adjacency.key = x$enadata$adjacency.matrix,
      codes = x$enadata$codes,
      nodes = x$node.positions
    )
  )
  class(newset) <- c("ena.set")
  class(newset$connection.counts) <- c("ena.connection", class(newset$connection.counts))

  return(newset);
}


as.matrix.ena.connection <- function(x, ...) {
  connection.matrix(x, ...)
}
