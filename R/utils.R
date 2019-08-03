
#' Find metadata columns
#'
#' @param data.table (or frame) to search for columns of class ena.metadata
#'
#' @return logical vector
#' @export
find.meta.cols <- function(x) {
   !sapply(x, is, class2="ena.metadata")
}

#' Find code columns
#'
#' @param data.table (or frame) to search for columns of class ena.co.occurrence
#'
#' @return logical vector
#' @export
find.code.cols <- function(x) {
   grepl("adjacency.code", x = names(x)) | sapply(x, function(col) {
     is(col, class2="ena.co.occurrence")
   })
}
remove.meta.data <- function(x) {
 x[,find.meta.cols(x), with=F]
}

#' Extract metadata easily
#'
#' @param x [TBD]
#' @param i [TBD]
#'
#' @return [TBD]
#' @export
"$.ena.metadata" = function(x, i) {
   parts = unlist(strsplit(x = as.character(sys.call())[2], split = "\\$"))[1:2]
   set = get(parts[1], envir = sys.frame(-2))
   m = set[[parts[2]]][x == i,]
   m
}

#' Extract line.weignts easily
#'
#' @param x [TBD]
#' @param i [TBD]
#'
#' @return [TBD]
#' @export
"$.line.weights" = function (x, i) {
   vals = x[[which(colnames(x) == i)]]
   unique.vals = unique(vals)
   # attr(vals, "values") <- unique.vals
   vals
}
#' Extract points easily
#'
#' @param x [TBD]
#' @param i [TBD]
#'
#' @return [TBD]
#' @export
"$.ena.points" = function (x, i) {
   vals = x[[which(colnames(x) == i)]]
   unique.vals = unique(vals)
   # attr(vals, "values") <- unique.vals
   vals
}
"$.ena.plots" <- function(x, i) {
 browser()
}
"[[.ena.plots" <- function(x, i) {
 browser()
}
#' @export
.DollarNames.ena.metadata = function(x, pattern="") {
 unique(x)
}
#' @export
summary.ena.set <- function(x) {
 print_dims <- function(n = 2) {
   cat("\t", paste("Dimension", 1:n, collapse = "\t"), "\n")
 }
 cat("Units: ", nrow(x$points), "\t\t")
 cat("Codes: ", length(x$rotation$codes), "\n")
 cat("Variance: \n")
 print_dims()
 cat("\t", paste(round(x$model$variance[1:2], 3), collapse="\t\t"), "\n\n")
 cat("Eigenvalues: \n")
 print_dims()
 cat("\t", paste(round(x$rotation$eigenvalues[1:2], 3), collapse="\t\t"), "\n\n")
 cat("Correlations: \n")
 cors = ena.correlations(x)
 rownames(cors) = paste("Dimension", 1:2)
 print(cors)
}
# as.data.frame.ena.connections <- function(x) {
#   class(x) = class(x)[-1]
#   y = as.data.frame(x)
#   y
# }
# format.co.occurrence = format.metadata = function(x, justify = "none") {
#   y = as.character(x)
#   format(y, justify = justify)
# }
