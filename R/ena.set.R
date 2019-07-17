ena.set <- function(x) {
  newset = list()
  class(newset) <- c("ena.set", class(newset))
  x.is.set = T

  if("ENAdata" %in% class(x)) {
    x = list(enadata = x);
    x.is.set = F
  }
  code.columns = apply(x$enadata$adjacency.matrix, 2, paste, collapse = " & ")

  newset$meta.data = x$enadata$metadata
  for(i in 1L:ncol(newset$meta.data))
    set(newset$meta.data, j = i, value = as.meta.data(newset$meta.data[[i]]))

  class(newset$meta.data) = c("meta.data", class(newset$meta.data))

  newset$connection.counts = x$enadata$adjacency.vectors;
  colnames(newset$connection.counts) = code.columns
  class(newset$connection.counts) <- c("ena.connection", class(newset$connection.counts))

  if(x.is.set) {
    newset$line.weights = as.data.table(cbind(x$enadata$metadata, x$line.weights))
    newset$points = cbind(x$enadata$metadata, x$points.rotated)
    newset$rotation.matrix = x$rotation.set$rotation
  }

  newset$trajectories = x$enadata$trajectories$step

  newset$model = list(
    model.type = x$enadata$model,
    raw.input = x$enadata$raw,
    row.connection.counts = x$enadata$accumulated.adjacency.vectors[, unique(names(x$enadata$accumulated.adjacency.vectors)), with=F],
    unit.labels = x$enadata$unit.names
  )

  if(x.is.set) {
    newset$model$centroids = x$centroids
    newset$model$correlations = x$correlations
    newset$model$function.call = x$function.call
    newset$model$function.params = x$function.params
    newset$model$points.for.projection = cbind(x$enadata$metadata, x$points.normed.centered)
    newset$model$variance = x$variance
  }

  newset$rotation = list(
    adjacency.key = x$enadata$adjacency.matrix,
    codes = x$enadata$codes
  )

  if(x.is.set) {
    newset$rotation$eigenvalues = x$rotation.set$eigenvalues
    newset$rotation$nodes = x$node.positions
    newset$rotation$rotation.matrix = x$rotation.set$rotation
  }

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

plot.ena.set <- function(x, ...) {
  if(is.null(x$model$plots)) {
    x$model$plots = list(
      base = ena.plot(x)
    )
    x
  } else {
    print(x$model$plots)
  }
}

points <- function(x, ...) {
  browser()
}

add_points <- function(x, wh = NULL, ...) {
  set = x
  # browser()
  args = as.character(substitute(wh))
  if(!is.null(args)) {
    cc = call("$", set$points, args[[2]])
    part1 = eval(cc)
    points = part1[args[[3]], "points" ,set]
    name = args[[length(args)]]
  } else {
    points = as.matrix(set$points)
    name = "all.points"
  }

  set$model$plots[[name]] = ena.plot.points(x$model$plots$base, points = points, ...)

  set
}

# colMeans <- function(x) {
#   if( is(x, "line.weights" ) ) {
#     browser()
#   }
#   base::colMeans(x)
# }

as.meta.data <- function(x) {
  if(is.factor(x)) {
    x = as.character(x)
  }
  class(x) = c("meta.data", class(x))
  x
}

remove.meta.data <- function(x) {
  x[,!sapply(x, is, class2="meta.data"), with=F]
}

as.matrix.line.weights <- function(x) {
  class(x) = class(x)[-1]
  x = remove.meta.data(x)
  as.matrix(x)
}

as.matrix.ena.points <- function(x) {
  class(x) = class(x)[-1]
  x = remove.meta.data(x)
  as.matrix(x)
}

"[.line.weights" = function (x, i, j, value) {
  class(x) = class(x)[-1]
  x = remove.meta.data(x)
  as.matrix(x[i,])
}

"[.ena.points" = function (x, i, j, value) {
  class(x) = class(x)[-1]
  x = remove.meta.data(x)
  as.matrix(x[i,])
}

"[.meta.data" = function(x, i, j, value) {
  if(is.null(value) || is.null(j)) {
    parts = unlist(strsplit(x = as.character(sys.call())[2], split = "\\$"))[1:2]

    if(is.null(value))
      set = get(parts[1], envir = sys.frame(-2))
  } else {
    set = value
  }

  if(is.null(j))
    wh = set[[parts[2]]]
  else
    wh = set[[j]]

  wh[x ==i,]
}
"$.meta.data" = function(x, i) {
  browser()
  parts = unlist(strsplit(x = as.character(sys.call())[2], split = "\\$"))[1:2]
  set = get(parts[1], envir = sys.frame(-2))
  set[[parts[2]]][x == i,]
}
# print.ena.set = function(x) {
#   browser()
# }
