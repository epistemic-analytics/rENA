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
    set(newset$meta.data, j = i, value = as.metadata(newset$meta.data[[i]]))

  class(newset$meta.data) = c("metadata", class(newset$meta.data))

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

as.matrix.line.weights <- function(x, square = F) {
  class(x) = class(x)[-1]

  rows = x[,find.meta.cols(x), with = F]
  if(square) {
    cm = sapply(seq(nrow(rows)), function(unit) {
      m = matrix(
        rep(NA, number^2),
        ncol =  number,
        nrow =  number,
        dimnames = list(codes, codes)
      )
      m[upper.tri(m)] = as.numeric(rows[unit,])
      m
    }, simplify = F);
    cm
  } else {
    as.matrix(rows)
  }
}

as.matrix.ena.points <- function(x) {
  class(x) = class(x)[-1]
  x = remove.meta.data(x)
  as.matrix(x)
}

# print.connection.matrix <- function(x, ...) {
#   # If this is left as NULL, we need to be able to figure out the set/object
#   # it is attached to when accessing it
#   browser()
# }

plot.ena.set <- function(x, ...) {
  # if(is.null(x$model$plots)) {
  ena.plot(x, ...)
  # } else {
  #   print(x$model$plots)
  # }
}

points <- function(x, wh = NULL, mean = F, labels = T, label.text = NULL, ...) {
  set = x$enaset
  parts = as.character(substitute(wh))
  points = set$points[set$points[[parts[2]]] == parts[3],]


  if(labels && is.null(label.text)) {
    label.values = as.character(points$ENA_UNIT);
  }

  if(mean == T) {
    # browser()
    x = group(x, points = colMeans(points), labels = parts[3], legend.name = parts[3], ...)
  }
  x = ena.plot.points(x, points = as.matrix(points), labels = label.values, legend.name = paste0(parts[3],".","points"), ...)

  x
}

add_points <- function(x, wh = NULL, name = "plot", ...) {
  set = x
  # browser()
  args = as.character(substitute(wh))
  if(!is.null(args) && length(args) > 1) {
    cc = call("$", set$points, args[[2]])
    part1 = eval(cc)
    points = part1[args[[3]], "points" ,set]
    name = args[[length(args)]]
  } else {
    points = as.matrix(set$points)
    name = "all.points"
  }

  set$model$plots[[name]] = ena.plot.points(x$model$plots[[name]], points = points, ...)

  set
}

#' @export
group <- function(x, wh = NULL,  ...) {
  set = x$enaset
  args = list(...)
  wh.clean = substitute(wh)

  if(identical(as.character(wh.clean), "wh.clean") || identical(as.character(wh.clean), "y")) {
    wh.clean = wh;
  }

  if(is.null(wh.clean)) { #, "ena.points")) {
    x = ena.plot.group(x, ...)
  } else {
    parts = as.character(wh.clean)
    label = parts[3]
    group.means = colMeans(set$points[set$points[[parts[2]]] == parts[3],])

    x = ena.plot.group(x, points = group.means, labels = label, ...)
  }

  x
}

#' @export
network <- function(x, wh = NULL, with.mean = T, ...) {
  set = x$enaset
  wh.clean = substitute(wh)
  args = list(...)

  if(is.null(wh.clean)) { #, "ena.points")) {
    x = ena.plot.network(x, network = colMeans(x$enaset$line.weights), points = x$enaset$rotation$nodes[,1:2] ,...)
    if(with.mean) {
      x = group(x, ...)
    }
  } else {
    parts = as.character(wh.clean)
    if(is.call(wh.clean[[2]])) {
      means = sapply(c(wh.clean[[2]], wh.clean[[3]]), function(y) {
        parts = as.character(y)

        if(with.mean)
          x = group(x, y, colors = default.colors[length(attr(x, "means"))+1], ...)

        colMeans(set$line.weights[set$line.weights[[parts[2]]] == parts[3],])
      })

      group.means = means[,1] - means[,2]
    } else {
      group.means = colMeans(set$line.weights[set$line.weights[[parts[2]]] == parts[3],])

      if(with.mean)
        x = group(x, wh.clean, ...)
    }

    x = ena.plot.network(x, network = group.means, points = x$enaset$rotation$nodes[,1:2], ...)
  }

  x
}

# colMeans <- function(x) {
#   if( is(x, "line.weights" ) ) {
#     browser()
#   }
#   base::colMeans(x)
# }

as.metadata <- function(x) {
  if(is.factor(x)) {
    x = as.character(x)
  }
  class(x) = c("metadata") #, class(x))
  x
}

find.meta.cols <- function(x) {
  !sapply(x, is, class2="metadata")
}

remove.meta.data <- function(x) {
  x[,find.meta.cols(x), with=F]
}


# "[.ena.points" = function (x, i, j, value) {
#   class(x) = class(x)[-1]
#   x = remove.meta.data(x)
#   as.matrix(x[i,])
# }
# "[.line.weights" = function (x, i, j, value, internal = F) {
#   browser()
#   orig.class = class(x)
#   class(x) = class(x)[-1]
#
#   if(internal == F) {
#   } else {
#     x = remove.meta.data(x)
#   }
#
#   m = x[i,]
#   class(m) = orig.class #c(orig.class, class(m))
#   m
# }
"$.line.weights" = function (x, i) {
  vals = x[[which(colnames(x) == i)]]
  unique.vals = unique(vals)
  # attr(vals, "values") <- unique.vals
  vals
}
"$.ena.points" = function (x, i) {
  vals = x[[which(colnames(x) == i)]]
  unique.vals = unique(vals)
  # attr(vals, "values") <- unique.vals
  vals
}

# "[.metadata" = function(x, i, j = NULL, value = NULL) {
#   browser();
#   if(is.null(value) || is.null(j)) {
#     parts = unlist(strsplit(x = as.character(sys.call())[2], split = "\\$"))[1:2]
#
#     if(is.null(value))
#       set = get(parts[1], envir = sys.frame(-2))
#   } else {
#     set = value
#   }
#
#   if(is.null(j))
#     wh = set[[parts[2]]]
#   else
#     wh = set[[j]]
#
#   wh[x ==i,]
# }
"$.metadata" = function(x, i) {
  parts = unlist(strsplit(x = as.character(sys.call())[2], split = "\\$"))[1:2]
  set = get(parts[1], envir = sys.frame(-2))
  m = set[[parts[2]]][x == i,]

  m
}

"$.ena.plots" <- function(x, i) {
  browser()
}
"[[.ena.plots" <- function(x, i) {
  browser()
}

#' @export
.DollarNames.metadata = function(x, pattern="") {
  unique(x)
}

