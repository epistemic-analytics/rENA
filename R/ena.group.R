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
#' @param points matrix (optional)
#' @param by vector to segment data using
#' @param method Function referance
#'
#' @keywords ENA, set, group
#'
#' @seealso
#'
#' @examples
#' \dontrun{
#' #Given an \code{\link{ENAset}}
#' ena.group(\code{\link{ENAset}})
#' }
#'
#' @return \code{\link{dataframe}}
##

ena.group <- function(
  enaset = NULL,   #ENAset object to form groups from
  points = NULL,

  by = NULL, #Vector of values  the same length as units.

  method = mean  #method by which to form groups from specified attribute/vector of values
) {
  run.method = function(pts) {
    points.dt = data.table::data.table(pts);
    points.dt.means = points.dt[, lapply(.SD,method), by=by];
    return(data.frame(points.dt.means[,colnames(points.dt),with=F],row.names=points.dt.means$by))
  }

  if(!is.null(enaset)) {
    group.points <- aggregate(enaset$points.rotated, list(by), method);
    group.weights <- aggregate(enaset$line.weights, list(by), method);

    return(list(
      "points" = run.method(enaset$points.rotated),
      "line.weights" = run.method(enaset$line.weights)
    ));
  } else {
    #browser()
    return(run.method(points))
  }
}
