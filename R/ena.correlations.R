###
#' Calculate the correlations
#'
#' @description Calculate both Spearman and Pearson correlations for the
#' provided ENAset
#'
#' @param enaset ENAset to run correlations on
#' @param dims The dimensions to calculate the correlations for. Default: c(1,2)
#'
#' @return Matrix of 2 columns, one for each correlation method, with the corresponding
#' correlations per dimension as the rows.
#'
#' @export
###
ena.correlations <- function(enaset, dims = c(1:2)) {
  pComb = combn(nrow(enaset$points),2)
  point1 = pComb[1,]
  point2 = pComb[2,]

  points = as.matrix(enaset$points)
  svdDiff = matrix(points[point1, dims] - points[point2, dims], ncol=length(dims), nrow=length(point1))
  optDiff = matrix(enaset$model$centroids[point1, dims] - enaset$model$centroids[point2, dims], ncol=length(dims), nrow=length(point1))

  correlations = as.data.frame(mapply(function(method) {
    lapply(dims, function(dim) {
      cor(as.numeric(svdDiff[,dim]), as.numeric(optDiff[,dim]), method=method)
    });
  }, c("pearson","spearman")))

  return(correlations);
}
