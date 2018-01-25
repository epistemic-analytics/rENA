###
#' Calculate the correlations
#'
#' @description Calculate the correlations for the provided ENAset
#'
#' @param enaset ENAset to run correclations for
#' @export
###
ena.correlations <- function(enaset) {
  pComb = combn(nrow(enaset$points.rotated),2)
  point1 = pComb[1,]
  point2 = pComb[2,]

  svdDiff = matrix(enaset$points.rotated[point1,] - enaset$points.rotated[point2,], ncol=ncol(enaset$points.rotated))
  optDiff = matrix(enaset$centroids[point1,] - enaset$centroids[point2,], ncol=ncol(enaset$centroids))

  correlations = as.data.frame(mapply(function(method) {
    lapply(1:ncol(enaset$points.rotated), function(dim) {
      cor(as.numeric(svdDiff[,dim]), as.numeric(optDiff[,dim]), method=method)
    });
  }, c("pearson","spearman")))

  return(correlations);
}
