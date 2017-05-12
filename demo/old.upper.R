R.upper.tri <- function(v) {
  matrix = v %*% t(v)
  matrix[upper.tri(matrix)]
}

R.upper.tri.2 <- function(v) {
  matrix = tcrossprod(v)
  matrix[upper.tri(matrix)]
}
