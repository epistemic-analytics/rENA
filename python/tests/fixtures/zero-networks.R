# Reference for python/tests/test_zero_networks.py and
# julia/test/models.jl (a copy of the JSON lives in julia/test/fixtures/):
# rENA's model() (SVD rotation) on RS.data accumulated by UserName, Condition
# and GroupName at window 4, which leaves two units with an empty (all-zero)
# network in the unordered set and one in the ordered set. With
# exclude_zero_networks = TRUE (the default; ena.make.set's
# center.align.to.origin = TRUE) those units sit at the origin, are left out
# of the centering mean and the node fit, and have zero centroids; for the
# unordered set the nodes and centroids are shifted so the fitted units' mean
# centroid is at the origin. exclude_zero_networks = FALSE is
# center.align.to.origin = FALSE: the mean over every unit, every unit shifted.
# From the repo root:  Rscript python/tests/fixtures/zero-networks.R
suppressMessages(devtools::load_all(quiet = TRUE))
data(RS.data)
codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
           "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
units <- c("UserName", "Condition", "GroupName")
conv  <- c("Condition", "GroupName")
d <- as.data.frame(RS.data)[, c(units, codes)]

m <- function(x) unname(as.matrix(x))
case <- function(acc, exclude) {
  set <- suppressWarnings(model(acc, rotate_fun = ena.rotate.by.svd, exclude_zero_networks = exclude))
  key <- as.matrix(set$rotation$adjacency.key)
  k <- min(6, ncol(as.matrix(set$points)))
  list(units = as.character(set$meta.data$ENA_UNIT),
       empty = as.list(which(rowSums(m(set$line.weights)) == 0)),
       adjacency_key = lapply(seq_len(ncol(key)), function(j) key[, j]),
       connection_counts = m(acc$connection.counts),
       line_weights = m(set$line.weights),
       points = m(set$points)[, 1:k],
       nodes = m(set$rotation$nodes)[, 1:k],
       centroids = m(set$model$centroids)[, 1:k],
       eigenvalues = unname(as.numeric(set$rotation$eigenvalues))[1:k],
       variance = unname(as.numeric(set$model$variance))[1:k],
       exclude_zero_networks = exclude)
}
acc <- function(ordered) suppressWarnings(accumulate(d, units, codes, conv, default_window = 4, ordered = ordered))
unordered <- acc(FALSE); ordered <- acc(TRUE)
out <- list(
  generator = "python/tests/fixtures/zero-networks.R",
  rENA = as.character(packageVersion("rENA")),
  codes = codes, units_by = units, conversations_by = conv, window = 4,
  unordered = case(unordered, TRUE),
  unordered_all = case(unordered, FALSE),
  ordered = case(ordered, TRUE),
  ordered_all = case(ordered, FALSE)
)
stopifnot(length(out$unordered$empty) == 2, length(out$ordered$empty) == 1)
f <- "python/tests/fixtures/zero-networks.json"
jsonlite::write_json(out, f, digits = NA, auto_unbox = TRUE, dataframe = "columns", matrix = "rowmajor")
file.copy(f, "julia/test/fixtures/zero-networks.json", overwrite = TRUE)
cat("wrote", f, "and julia/test/fixtures/zero-networks.json\n")
