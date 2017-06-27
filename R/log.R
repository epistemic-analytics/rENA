##
#' @title Alternate log function
#'
#' @description adds 1 before computing to avoid indef. results from zeros
#'
#' @details [TBD]
#'
#' @export
#'


log = function(x) {

   x = base::log(x + 1);

   x;

}
