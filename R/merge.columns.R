merge.columns <- function(x, from.cols, new.col = NULL) {
  if(!is.null(new.col)) {
    x[[new.col]] = x[,{apply(.SD,1,function(x){paste(trimws(x),collapse=".")})},with=T,.SDcols=from.cols];
    x
  } else {
    x[,{apply(.SD,1,function(x){paste(trimws(x),collapse=".")})},with=T,.SDcols=from.cols];
  }
}
