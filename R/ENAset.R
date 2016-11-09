ENAset = R6Class("ENAset",
  public = list(
    initialize = function(centeredData, rotation, ...) {
      private$centeredData <- centeredData;
      private$rotation <- rotation;
    },
    space = list(),
    set_centeredData = function(d) {
      private$centeredData <- d;
    },
    get_centeredData = function() {
      private$centeredData;
    },
    get_rawCoordinates = function(loadings = private$rotation) {
      if(!is.null(loadings)) {

      }
      private$centeredData %*% loadings;
    }
  ),
  private = list(
    rotation = NULL,
    centeredData = NULL
  )
)
set = ENAset$new(centeredData2, rotatedC2)
