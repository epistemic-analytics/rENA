##
#' @title Aggregate groups of points by arbitrary method
#'
#' @description Aggregates ena data to groups, including point locations and edge weights, by a provided vector, using the specified function
#'
#' @details [TBD]
#'
#' @export
#'
#' @param enaset An \code{\link{ENAset}} (optional)
#' @param by A vector of values the same length as units. Uses rotated points for group positions and normed data to get the group edge weights
#' @param method A function that is used on grouped points. Default: mean()
#'
#' @keywords ENA, set, group
#'#'
#' @examples
#' \dontrun{
#' #Given an \code{\link{ENAset}}
#' ena.group(\code{\link{ENAset}})
#' }
#'
#' @return A list containing names, points, and edge weights for each of the unique groups formed by the function
##
ena.group <- function(
  enaset = NULL,   #ENAset object to form groups from
  by = NULL, #Vector of values  the same length as units.
  method = mean  #method by which to form groups from specified attribute/vector of values
) {
  run.method = function(pts) {
    points.dt = data.table::data.table(pts);
    if(is.logical(by)) {
      points.dt.means = points.dt[by, lapply(.SD,method),]; # by=by];
    } else {
      points.dt.means = points.dt[, lapply(.SD,method), by=by];
    }
    return(as.data.frame(points.dt.means[,colnames(points.dt),with=F]))
  }

  if(is.character(method)) {
    method = get(method)
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
