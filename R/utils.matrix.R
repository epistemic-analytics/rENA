#' @export
as.matrix.ena.connection <- function(x, ...) {
  connection.matrix(x, ...)
}
#' @export
as.matrix.ena.line.weights <- function(x, square = ifelse(nrow(x) > 1, F, T)) {
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
  } else {
   as.matrix(rows)
  }
}
#' @export
as.matrix.ena.rotation.matrix <- function(x) {
  class(x) = class(x)[-1]
  x = remove.meta.data(x)
  as.matrix(x)
}
#' @export
as.matrix.ena.points <- function(x) {
  class(x) = class(x)[-1]
  x = remove.meta.data(x)
  as.matrix(x)
}
#' @export
as.matrix.ena.nodes <- function(x) {
  class(x) = class(x)[-1]
  as.matrix(x[,-c("code")])
}

#' ENA Connections as a matrix
#'
#' @param x ena.connections object
#' @param square Logical. If TRUE, each row is converted to a square matrix
#' @param names Ignored
#'
#' @return If square is FALSE (default), a matrix with all metadata columns removed, otherwise a list with square matrices
#' @export
as.matrix.ena.connections <- function(x, square = ifelse(nrow(x) > 1, F, T), names = NULL, simplify = ifelse(nrow(x) > 1, F, T)) {
  class(x) = class(x)[-1]
  x = remove.meta.data(x)
  rows = x[,find.meta.cols(x), with = F]
  if(square) {
    upperTriSize = ncol(rows)
    number = ( (ceiling(sqrt(2*upperTriSize)) ^ 2) ) - (2*upperTriSize)
    cm = sapply(seq(nrow(rows)), function(unit) {
    m = matrix(
      rep(NA, number^2),
      ncol =  number,
      nrow =  number,
      dimnames = list(codes, codes)
    )
    m[upper.tri(m)] = as.numeric(rows[unit,])
    m
    }, simplify = F)

    if(simplify) {
      cm = cm[[1]]
    } else {
      names(cm) = names
    }
  } else {
    cm = as.matrix(rows)
    rownames(cm) = names
  }

  cm
}
