ena.set <- function(x) {

  newset = list()
  class(newset) <- c("ena.set")

  newset$connection.counts = x$points.raw
  newset$line.weights = x$line.weights
  newset$meta.data = x$enadata$raw
  newset$points = x$points.rotated
  newset$rotation.matrix = x$rotation.set$rotation
  newset$trajectories = x$enadata$trajectories$step
  newset$units = x$enadata$units
  newset$model = list(
    model.type = x$enadata$model,
    centroids = x$centroids,
    correlations = x$correlations,
    points.for.projection = x$points.normed.centered,
    variance = x$variance,
    function.call = x$function.call,
    function.params = x$function.params,
    row.connection.counts = x$enadata$accumulated.adjacency.vectors,
    unit.labels = x$enadata$unit.names
  )
  newset$rotation = list(
    eigenvalues = x$rotation.set$eigenvalues,
    rotation.matrix = x$rotation.set$rotation,
    adjacency.key = x$enadata$adjacency.matrix,
    codes = x$enadata$codes,
    nodes = x$node.positions
  )
  class(newset$connection.counts) <- c("ena.connection", class(newset$connection.counts))


  conn.env = new.env(parent = globalenv())
  class(conn.env) = 'pointer'

  connection.matrices = vector(mode = "list", length = length(set2$model$unit.labels))
  names(connection.matrices) = set2$model$unit.labels

  conn.env = list2env(connection.matrices)
  for(l in set2$model$unit.labels) {
    delayedAssign(l, {
      print(Sys.time())
      connection.matrix(newset$connection.counts, l)
    }, assign.env = conn.env)
  }

  newset$connection.matrices = conn.env
  class(connection.matrices) <- c("connection.matrix", class(connection.matrices))
  # attr(connection.matrices, "ena.set") <- newset;
  # matrices.object = new.env(parent = globalenv())
  # matrices.object$value = connection.matrices
  # class(matrices.object) = 'pointer'

  # object.set$value = newset

  # browser()

  return(newset);
}


as.matrix.ena.connection <- function(x, ...) {
  connection.matrix(x, ...)
}

# print.connection.matrix <- function(x, ...) {
#   # If this is left as NULL, we need to be able to figure out the set/object
#   # it is attached to when accessing it
#   browser()
# }
