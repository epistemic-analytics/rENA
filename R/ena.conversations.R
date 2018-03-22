##
#' @title Find conversations by unit
#'
#' @description Find rows of conversations by unit
#'
#' @details [TBD]
#'
#' @param data [TBD]
#' @param units [TBD]
#' @param units.by [TBD]
#' @param conversation.by [TBD]
#' @param window [TBD]
#' @param codes [TBD]
#'
#' @export
#' @return list containing the accumulation and set
##
ena.conversations = function(set, units, units.by, conversation.by, window, codes=NULL, conversation.exclude = c()) {
  rows = sapply(set$enadata$raw[, paste(.I,collapse=","), by=c(conversation.by)]$V1, function(x) as.numeric(unlist(strsplit(x, split=","))),USE.NAMES = T)
  names(rows) = unique(set$enadata$accumulated.adjacency.vectors[,KEYCOL])
  adjCol = set$enadata$adjacency.matrix[1,] %in%  codes[1] & set$enadata$adjacency.matrix[2,] %in% codes[2]
  adjColName = paste("adjacency.code.", which(adjCol), sep = "")
  unitRows = merge_columns_c(set$enadata$accumulated.adjacency.vectors[,c(units.by),with=F], units.by)
  codedUnitRows = which(unitRows %in% units & set$enadata$accumulated.adjacency.vectors[[adjColName]] == 1)
  codedUnitRowConvs = set$enadata$accumulated.adjacency.vectors[codedUnitRows,KEYCOL]

  codedUnitRowConvsAll = unique(unlist(sapply(1:length(codedUnitRows), function(x) {
    theseRows = rows[[codedUnitRowConvs[x]]]
    thisOne = which(theseRows %in% codedUnitRows[x])
    thisAll = seq.int(thisOne-3,thisOne)
    theseRows[thisAll[thisAll > 0]]
  })))
  browser()
  return(list(
    conversations = rows,
    unitConvs = unique(set$enadata$accumulated.adjacency.vectors[codedUnitRows,KEYCOL]),
    allRows = codedUnitRowConvsAll,
    unitRows = codedUnitRows
  ));
}
