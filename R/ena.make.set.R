##
#' @title Generate ENA Set
#' @description Generate an ENA set from a givent ENA data object
#'
#'
#'
#' @export
##
ena.make.set <- function(
  ...,
  output = "class"
) {
  set = ENAset$new(...)$process();
  if(output == "json") r6.to.json(set)
  else set
}
