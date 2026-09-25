context("accumulate() weight_by")

codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
           "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
units <- c("Condition", "UserName")
horizon <- c("Condition", "GroupName")

unit_matrix <- function(accum) {
  m <- as.matrix(accum$connection.counts)
  rownames(m) <- as.character(accum$connection.counts$ENA_UNIT)
  m
}

test_that("weight_by matches the legacy ena.accumulate.data weight.by on RS.data", {
  data(RS.data)
  legacy_weight <- list(binary = "binary", product = "product", sqrt = sqrt, log1p = log1p)
  for (w in names(legacy_weight)) {
    legacy <- suppressWarnings(ena.accumulate.data(
      units = RS.data[, units], conversation = RS.data[, horizon],
      codes = RS.data[, codes], window.size.back = 4, weight.by = legacy_weight[[w]]))
    expected <- unit_matrix(legacy)

    got <- unit_matrix(accumulate(RS.data, units, codes, horizon,
                                  default_window = 4, weight_by = w))
    expect_equal(got, expected[rownames(got), ], tolerance = 1e-12, info = w)
  }
})

test_that("weight_by defaults follow binary and are recorded on the set", {
  data(RS.data)
  acc <- function(...) unit_matrix(accumulate(RS.data, units, codes, horizon, default_window = 4, ...))
  expect_equal(acc(), acc(weight_by = "binary"))
  expect_equal(acc(binary = FALSE), acc(weight_by = "product"))
  set <- accumulate(RS.data, units, codes, horizon, default_window = 4, weight_by = "sqrt")
  expect_equal(set$`_function.params`$weight_by, "sqrt")
  expect_error(accumulate(RS.data, units, codes, horizon, weight_by = "cube"), "Unknown weight model")
})

test_that("ordered: binary keeps raw directed counts; sqrt weights per directed cell", {
  data(RS.data)
  acc <- function(w) accumulate(RS.data, units, codes, horizon, default_window = 4,
                                ordered = TRUE, weight_by = w)
  expect_equal(unit_matrix(acc("binary")), unit_matrix(acc("product")))
  sq <- acc("sqrt")
  rows <- sq$model$row.connection.counts
  conn <- setdiff(colnames(rows), c("QEID", "QEUNIT", units))
  expected <- rows[, lapply(.SD, function(x) sum(sqrt(x))), by = units, .SDcols = conn]
  expect_equal(unname(unit_matrix(sq)), unname(as.matrix(as.data.frame(expected)[, conn])))
})

test_that("weighted accumulations build a full model", {
  data(RS.data)
  for (w in c("sqrt", "log1p")) {
    set <- model(accumulate(RS.data, units, codes, horizon, default_window = 4, weight_by = w))
    expect_equal(nrow(as.matrix(set$points)), 48, info = w)
    expect_true(all(is.finite(as.matrix(set$points))), info = w)
  }
})
