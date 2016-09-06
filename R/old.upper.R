old.upper <- function(v) {
  matrix = v %*% t(v)
  matrix[upper.tri(matrix)]
}

