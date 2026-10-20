##
#' @title Names to Adjacency Key
#'
#' @description Convert a vector of strings, representing names of a square matrix, to an adjacency
#'
#' @details Returns a matrix of 2 rows by choose(length(vector), 2) columns,
#' or by \code{n * (n + 1) / 2} columns when \code{diagonal} is \code{TRUE}
#' (the self-connection layout: upper triangle with the diagonal, column-major,
#' e.g. A & A, A & B, B & B, A & C, B & C, C & C).
#'
#' @param vector Vector representing the names of a square matrix
#' @param upper_triangle Not Implemented
#' @param diagonal Logical, include the diagonal (self-connections). Default FALSE
#'
#' @export
##
namesToAdjacencyKey <- function(vector, upper_triangle = TRUE, diagonal = FALSE) {
  if (isTRUE(diagonal)) {
    n <- length(vector)
    j <- rep(seq_len(n), seq_len(n))
    i <- sequence(seq_len(n))
    return(matrix(vector[rbind(i, j)], nrow = 2))
  }
  upperTriIndices = triIndices(length(vector)) + 1;
  matrix(vector[upperTriIndices], nrow=2)
}
