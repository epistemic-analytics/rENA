##
#' @title Aggregate groups of points by arbitrary method
#'
#' @description Uses rotated points for group positions and normed data to get
#' the group edge weights
#'
#' @details [TBD]
#'
#' @export
#'
#' @param enaset ENAset (optional)
#' @param by vector to segment data using
#' @param method Function referance
#'
#' @keywords ENA, set, group
#'#'
#' @examples
#' \dontrun{
#' #Given an \code{\link{ENAset}}
#' ena.group(\code{\link{ENAset}})
#' }
#'
#' @return \code{\link{data.frame}}
##
ena.group <- function(
  enaset = NULL,   #ENAset object to form groups from
  by = NULL, #Vector of values  the same length as units.
  method = mean  #method by which to form groups from specified attribute/vector of values
) {
  run.method = function(pts) {
    points.dt = data.table::data.table(pts);
    points.dt.means = points.dt[, lapply(.SD,method), by=by];
    return(as.data.frame(points.dt.means[,colnames(points.dt),with=F]))
  }

  if("ENAset" %in% class(enaset)) {
    return(list(
      "names" = as.vector(unique(by)),
      "points" = run.method(enaset$points.rotated),
      "line.weights" = run.method(enaset$line.weights)
    ));
  } else {
    return(run.method(enaset))
  }
}
