###
#' @title ENA SVD
#' @description ENA method for rotation using SVD
#' @param self [TBD]
#' @param ... [TBD]
#' @export
###
ena.svd <- function(self, ...) {
  to.norm = data.table::data.table(
    self$points.normed.centered,
    merge_columns_c(
      attr(
        self$points.normed.centered,
        rENA::opts$UNIT_NAMES
      ),
      self$enadata$get("units.by")
    )
  )
  to.norm = as.matrix(to.norm[,tail(.SD,n=1),.SDcols=colnames(to.norm)[which(colnames(to.norm) != "V2")],by=c("V2")][,2:ncol(to.norm)]);

  pcaResults = pca_c(to.norm, dims = self$get("dimensions"));

  ### used to be  self$data$centered$pca
  self$rotation.set = pcaResults$pca;
  ### used to be self$data$centered$latent
  self$variance = pcaResults$latent[self$get("dimensions")];

  rotationSet = ENARotationSet$new(rotation = pcaResults$pca, codes = self$codes, node.positions = NULL)
  return(rotationSet)
}
