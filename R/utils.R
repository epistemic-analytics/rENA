
#' Find metadata columns
#'
#' @param x data.table (or frame) to search for columns of class ena.metadata
#'
#' @return logical vector
#' @export
find.meta.cols <- function(x) {
   !sapply(x, is, class2 = "ena.metadata")
}

#' Find code columns
#'
#' @param x data.table (or frame) to search for columns of class ena.co.occurrence
#'
#' @return logical vector
#' @export
find.code.cols <- function(x) {
   grepl("adjacency.code", x = names(x)) | sapply(x, function(col) {
     is(col, class2 = "ena.co.occurrence")
   })
}

#' Find dimension columns
#'
#' @param x data.table (or frame) to search for columns of class ena.dimension
#'
#' @return logical vector
#' @export
find.dimension.cols <- function(x) {
   sapply(x, is, class2 = "ena.dimension")
}

#' Remove meta columns from data.table
#'
#' @param x [TBD]
#'
#' @return data.table withe columns of class ena.meta.data removed
#' @export
remove.meta.data <- function(x) {
 x[, find.meta.cols(x), with = F]
}

#' Extract metadata easily
#'
#' @param x [TBD]
#' @param i [TBD]
#'
#' @return [TBD]
#' @export
"$.ena.metadata" <- function(x, i) {
   #browser()
   parts <- unlist(strsplit(
               x = as.character(sys.call())[2], split = "\\$"
            ))[1:2]

   set <- get(parts[1], envir = parent.frame())
   m <- set[[parts[2]]][x == i, ]
   m
}

#' Extract line.weignts easily
#'
#' @param x [TBD]
#' @param i [TBD]
#'
#' @return [TBD]
#' @export
"$.line.weights" <- function (x, i) {
   vals <- x[[which(colnames(x) == i)]]

   vals
}

#' Extract points easily
#'
#' @param x [TBD]
#' @param i [TBD]
#'
#' @return [TBD]
#' @export
"$.ena.points" <- function (x, i) {
   vals <- x[[which(colnames(x) == i)]]

   vals
}
# "$.ena.plot" <- function(x, i) {
#  browser()
# }
# "[[.ena.plot" <- function(x, i) {
#  browser()
# }
#' @export
.DollarNames.ena.metadata <- function(x, pattern = "") {
   unique(x)
}

# "[.ena.matrix" = function(x, ...)
# {
#    browser()
#    original.class = class(x)[1]
#    class(x) = class(x)[-1]
#    x = x[...]
#
# #   y = as.data.frame(x)
# }

#' @export
summary.ena.set <- function(object, ...) {
   x <- object
   print_dims <- function(n = 2) {
      cat("\t", paste("Dimension", 1:n, collapse = "\t"), "\n")
   }
   cat("Units: ", nrow(x$points), "\t\t")
   cat("Codes: ", length(x$rotation$codes), "\n")

   cat("Variance: \n")
   print_dims()
   cat("\t", paste(round(x$model$variance[1:2], 3), collapse = "\t\t"), "\n\n")

   cat("Eigenvalues: \n")
   print_dims()
   cat("\t", paste(round(
      x$rotation$eigenvalues[1:2], 3), collapse = "\t\t"), "\n\n")

   cat("Correlations: \n")
   cors <- ena.correlations(x)
   rownames(cors) <- paste("Dimension", 1:2)
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

#' Title
#'
#' @param x [TBD]
#' @param ... [TBD]
#'
#' @return [TBD]
#' @export
print.ena.set <- function(x, ..., plot = F, set = T) {
   x.unclass <- unclass(x)
   if(plot == F) {
      x.unclass$model$plots <- NULL
   }
   if(set == F) {
      x.unclass <- x.unclass$model$plots
   }
   base::print(x.unclass)
}

#' Title
#'
#' @param x [TBD]
#' @param ... [TBD]
#'
#' @return [TBD]
#' @export
show <- function(x, ...) {
   x$model$plots <- lapply(x$model$plots, check_range)
   print(x, ..., plot = T, set = F)

   invisible(x)
}
