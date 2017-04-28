##
#' @title Test SD
#' @description Test SD in data.table
#' @import data.table
#' @export
##
test.sd <- function(withSD = F) {
  dt = data.table::data.table(a=c(1,2,3,4,5,6), b=c(10,11,12,13,14,15), c=c(0.5));
  dtCols = c("a","b");

  dtFiltered = NULL;
  if(withSD == F) {
    dtFiltered  = dt[ dt$a < 4, dtCols, .SDcols = dtCols, with = F]
  } else {
    dtFiltered = dt[ dt$a < 4, .SD, .SDcols = dtCols, with = T];
  }


  return( dtFiltered )
}
