# Missed co-occurrences from tma::accumulate(misses = TRUE) (tma >= 0.3.7)
# carried through model(). Lives in rENA: rENA depends on tma, not the reverse.

misses_toy <- data.frame(
  u = c("x", "x", "x", "y", "y", "z", "w", "w"),
  c = c("1", "1", "1", "2", "2", "3", "4", "4"),
  A = c(2, 1, 0, 1, 1, 1, 0, 1),
  B = c(0, 3, 1, 1, 0, 1, 1, 1),
  C = c(1, 0, 2, 0, 1, 0, 1, 0)
);

misses_accum <- function(...) {
  ctx <- tma::contexts(misses_toy, units_by = "u",
                       hoo_rules = tma::conversation_rules((c %in% UNIT$c)));
  tensor <- tma::context_tensor(misses_toy, sender_cols = NULL, receiver_cols = NULL,
                                default_window = 3, default_weight = 1);
  tma::accumulate(context_model = ctx, codes = c("A", "B", "C"), tensor = tensor, ...)
}

test_that("tma misses survive model() unchanged", {
  for (ord in c(FALSE, TRUE)) {
    accum <- misses_accum(ordered = ord, misses = TRUE);
    set <- model(accum);
    info <- paste("ordered", ord);
    expect_equal(set$miss.counts, accum$miss.counts, info = info);
    expect_equal(set$model$row.miss.counts, accum$model$row.miss.counts, info = info);
    expect_true(set$`_function.params`$misses, info = info);
  }
})

test_that("tma misses do not change the fitted model", {
  for (ord in c(FALSE, TRUE)) {
    with_misses <- model(misses_accum(ordered = ord, misses = TRUE));
    plain       <- model(misses_accum(ordered = ord));
    info <- paste("ordered", ord);
    expect_equal(as.matrix(with_misses$line.weights),    as.matrix(plain$line.weights),    info = info);
    expect_equal(as.matrix(with_misses$rotation.matrix), as.matrix(plain$rotation.matrix), info = info);
    expect_equal(as.matrix(with_misses$points),          as.matrix(plain$points),          info = info);
    expect_equal(as.matrix(with_misses$rotation$nodes),  as.matrix(plain$rotation$nodes),  info = info);
    expect_equal(with_misses$model$variance,             plain$model$variance,             info = info);
  }
})
