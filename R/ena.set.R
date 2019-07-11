ena.set <- function(x) {

  newset = list()
  class(newset) <- c("ena.set", class(newset))


  code.columns = apply(x$enadata$adjacency.matrix, 2, paste, collapse = " & ")

  newset$connection.counts = x$points.raw
    colnames(newset$connection.counts) = code.columns
    class(newset$connection.counts) <- c("ena.connection", class(newset$connection.counts))

  newset$line.weights = as.data.table(cbind(x$enadata$metadata, x$line.weights))
  newset$meta.data = x$enadata$metadata
  newset$points = cbind(x$enadata$metadata, x$points.rotated)
  newset$rotation.matrix = x$rotation.set$rotation
  newset$trajectories = x$enadata$trajectories$step
  # newset$units = x$enadata$units

  newset$model = list(
    centroids = x$centroids,
    correlations = x$correlations,
    function.call = x$function.call,
    function.params = x$function.params,
    model.type = x$enadata$model,
    points.for.projection = cbind(x$enadata$metadata, x$points.normed.centered),
    raw.input = x$enadata$raw,
    row.connection.counts = x$enadata$accumulated.adjacency.vectors[, unique(names(x$enadata$accumulated.adjacency.vectors)), with=F],
    unit.labels = x$enadata$unit.names,
    variance = x$variance
  )


  newset$rotation = list(
    adjacency.key = x$enadata$adjacency.matrix,
    codes = x$enadata$codes,
    eigenvalues = x$rotation.set$eigenvalues,
    nodes = x$node.positions,
    rotation.matrix = x$rotation.set$rotation
  )


  conn.env = new.env(parent = globalenv())
  class(conn.env) = 'pointer'

  connection.matrices = vector(mode = "list", length = length(newset$model$unit.labels))
  names(connection.matrices) = newset$model$unit.labels

  conn.env = list2env(connection.matrices)
  for(l in newset$model$unit.labels) {
    delayedAssign(l, {
      connection.matrix(newset$connection.counts, l)
    }, assign.env = conn.env)
  }

  newset$connection.matrices = conn.env
  class(connection.matrices) <- c("connection.matrix", class(connection.matrices))
  # browser()

  # attr(connection.matrices, "ena.set") <- newset;
  # matrices.object = new.env(parent = globalenv())
  # matrices.object$value = connection.matrices
  # class(matrices.object) = 'pointer'

  # object.set$value = newset

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

# list(
#   connection.matrices = NULL,
#   connection.counts = NULL,
#   line.weights = NULL,
#   meta.data = NULL,
#   points = NULL,
#   rotation.matrix = NULL,
#   trajectories = NULL,
#
#   model = list(
#     centroids = NULL,
#     correlations = NULL,
#     function.call = NULL,
#     function.params = NULL,
#     model.type = NULL,
#     points.for.projection = NULL,
#     raw.input = NULL,
#     row.connection.counts = NULL,
#     unit.labels = NULL,
#     variance = NULL
#   ),
#
#   rotation = list(
#     adjacency.key = NULL,
#     codes = NULL,
#     eigenvalues = NULL,
#     nodes = NULL,
#     rotation.matrix = NULL
#   )
# )
