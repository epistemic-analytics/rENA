##
#' @title Clean Data File
#' @description Clean a data file for safer usage with ENA
#'
# @param
# @param
# @param
# @param
# @param
#'
# @return
# @export
##
ena.clean.data <- function(
  data.file,
  remove.na = FALSE,
  remove.na.by = NULL, # c("column", "row")
  split.columns = NULL,
  split.columns.by = ","
) {
  data.file.raw = data.file;

  if(is.character(data.file)) {
    data.file = data.table::fread(data.file);
  }
  else if(!is.data.frame(data.file)) {
    data.file = data.frame(data.file.raw);
  }


  if( !is.null(split.columns) ) {
    ## Use `split.columns.by` to split values in `split.columns`
  }
  if(remove.na == T) {
    ## Use `remove.na.by` to remove rows/cols that have NA values
  }

  return(data.file);
}
