##
#' @title Generate ENA Set
#'
#' @description Generates an ENA set from a given ENA data object.
#'
#' @details [TBD]
#'
#' @export
#'
#' @param enadata \code{\link{ENAdata}} that will be used to generate an ENA set
#' @param dims Number of dimensions in the set
#' @param samples [TBD]
#' @param inPar [TBD]
#' @param ... additional parameters addressed in inner function
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
  enaset,   #ENAset object to form groups from

  by = NULL, #Vector of values  the same length as units.
  #Uses rotated points for group positions and normed data to get the group edge weights

  method = mean,  #method by which to form groups from specified attribute/vector of values

  ...
) {

  ### FOR TESTING
  # enaset = df.set;
  # by = data.frame(by = rep(c(1,1,2,2,3,3), 8));
  # by = data.frame(by = rep(c("big","med","small","tiny","huge","large"), 8));
  # by = rep(c("big","med","small","tiny","huge","large"), 8);
  # method = mean;
  ###

  points <- as.data.table(enaset$points.rotated);
  weights <- as.data.table(enaset$line.weights);
  group.points.edges <- cbind(points, weights);

  group.points.edges <- aggregate(group.points.edges, list(by), method);

  return(group.points.edges);
}
