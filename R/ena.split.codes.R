###
#' @title Split code columns
#'
#' @description This function will split single code columns into binary columns.
#'
#' @export
#'
#' @param data.file The csv file location or data frame which has the columns to be split
#' @param split.columns The specific column in the The csv file or data frame that will be split
#' @param split.columns.by Delimits columns in The csv file or data frame that will be split
#' @param code.names The name for the codes resulting from the split columns in the The csv file or data.frame
#'
#' @keywords columns, split
#'
#' @seealso \code{\link{ena.accumulate.data}}, \code{\link{ena.make.set}}
#'
#' @examples
#' \dontrun{
#' #Given a csv file location
#' ena.split.codes(data = .csv)
#'
#' #Given a data frame
#' ena.split.codes(data = data.frame)
#' }
#' @return Data frame containing the split code columns
#'
###

ena.split.codes <- function(
  data.file,
  split.columns = NULL,
  split.columns.by = ",",
  code.names = NULL
) {
  data.file.raw = data.file;

  if(is.character(data.file)) {
    data.file = read.csv(data.file);
  }
  else if(!is.data.frame(data.file)) {
    data.file = data.frame(data.file.raw);
  }

  ## Use `split.columns.by` to split values in `split.columns`
  if( !is.null(split.columns) ) {
    for(col in split.columns) {
      split.column = matrix(unlist(data.table::tstrsplit(data.file[,col], split=split.columns.by, type.convert = T)), nrow=nrow(data.file))
      re.named = F;
      if(!is.null(code.names)) {
        if (col %in% names(code.names) ) {
          colnames(split.column) = code.names[[col]];
          re.named = T;
        } else if (length(split.columns) == 1 && length(code.names) == ncol(split.column))  {
          colnames(split.column) = code.names;
          re.named = T;
        }
      }
      if(re.named == F) {
        colnames(split.column) = paste(col,1:ncol(split.column),sep=".");
      }
      data.file = cbind(data.file,split.column);
      data.file = data.file[, -which(names(data.file) == col)];
    }
  }

  return(data.file);
}
