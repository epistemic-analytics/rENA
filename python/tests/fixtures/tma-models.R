# Reference for python/tests/test_tma_models.py: rENA's model() (SVD
# rotation) on tma's accumulate() of a toy data set -- ordered, unordered with
# self-connections, and plain unordered (product weights, window 3).
# From the repo root:  Rscript python/tests/fixtures/tma-models.R
suppressMessages(devtools::load_all(quiet = TRUE))
toy <- data.frame(u = c("x","x","x","y","y","z","w","w","v","v","v"),
                  c = c("1","1","1","2","2","3","4","4","5","5","5"),
                  A = c(2,1,0,1,1,1,0,1,1,0,1), B = c(0,3,1,1,0,1,1,1,0,1,1),
                  C = c(1,0,2,0,1,0,1,0,1,1,0))
ctx <- tma::contexts(toy, units_by = "u", hoo_rules = tma::conversation_rules((c %in% UNIT$c)))
ten <- tma::context_tensor(toy, NULL, NULL, default_window = 3, default_weight = 1)
case <- function(acc, self_weight = 2) {
  set <- suppressWarnings(model(acc, rotate_fun = ena.svd, self_weight = self_weight))
  key <- as.matrix(set$rotation$adjacency.key)
  list(units = as.character(set$meta.data$u),
       adjacency_key = lapply(seq_len(ncol(key)), function(k) key[, k]),
       connection_counts = unname(as.matrix(acc$connection.counts)),
       line_weights = unname(as.matrix(set$line.weights)),
       points = unname(as.matrix(set$points)[, 1:2]),
       nodes = unname(as.matrix(set$rotation$nodes)[, 1:2]),
       self_weight = self_weight)
}
acc <- function(...) tma::accumulate(ctx, c("A", "B", "C"), ten, weight_by = "product", ...)
out <- list(
  toy = toy, codes = c("A", "B", "C"),
  ordered = case(acc(ordered = TRUE)),
  ordered_self_weight_1 = case(acc(ordered = TRUE), self_weight = 1),
  self_connections = case(acc(self_connections = TRUE)),
  plain = case(acc())
)
jsonlite::write_json(out, "python/tests/fixtures/tma-models.json", digits = NA, auto_unbox = TRUE,
                     dataframe = "columns", matrix = "rowmajor", pretty = TRUE)
