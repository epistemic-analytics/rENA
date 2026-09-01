suppressMessages(library(rENA, quietly = TRUE, verbose = FALSE))
context("Test Cross-Covariance Decay (CCD) window size estimation")

test_that("ena.ccd.window returns valid integer window size on RS.data", {
  data(RS.data)
  codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
                 "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")

  w <- ena.ccd.window(
    x = RS.data,
    codeNames = codeNames,
    conversation_cols = c("Condition", "GroupName"),
    max_window = 20
  )

  testthat::expect_type(w, "integer")
  testthat::expect_length(w, 1)
  testthat::expect_true(w >= 1 && w <= 20)
  testthat::expect_equal(w, 6L)
})

test_that("ena.ccd returns an S3 object with correct structure and curves", {
  data(RS.data)
  codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
                 "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")

  res <- ena.ccd(
    x = RS.data,
    codeNames = codeNames,
    conversation_cols = c("Condition", "GroupName"),
    max_window = 15
  )

  testthat::expect_s3_class(res, "ena.ccd")
  testthat::expect_named(res, c("window_size", "peak_lag", "curves", "codeNames", "conversation_cols"))
  testthat::expect_equal(res$window_size, 6L)
  testthat::expect_equal(nrow(res$curves), 16) # lags 0:15
  testthat::expect_true(all(c("lag", "frob", "frob_sq_unbiased", "frob_unbiased_signed", "total_weight") %in% colnames(res$curves)))
  testthat::expect_true(all(res$curves$total_weight > 0))
})

test_that("ena.ccd and ena.ccd.window accept ENA accumulation objects directly", {
  data(RS.data)
  codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
                 "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")

  accum <- ena.accumulate.data(
    units = RS.data[, c("UserName", "Condition")],
    conversation = RS.data[, c("Condition", "GroupName")],
    codes = RS.data[, codeNames],
    window.size.back = 4
  )

  w_obj <- ena.ccd.window(accum)
  testthat::expect_equal(w_obj, 6L)

  ccd_obj <- ena.ccd(accum)
  testthat::expect_s3_class(ccd_obj, "ena.ccd")
  testthat::expect_equal(ccd_obj$window_size, 6L)
})

test_that("ena.tune.window.size defaults to ccd and updates accumulation window", {
  data(RS.data)
  codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
                 "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")

  accum <- ena.accumulate.data(
    units = RS.data[, c("UserName", "Condition")],
    conversation = RS.data[, c("Condition", "GroupName")],
    codes = RS.data[, codeNames],
    window.size.back = 2
  )

  tuned <- ena.tune.window.size(accum, method = "ccd")
  testthat::expect_true(inherits(tuned, c("ENAdata", "ena.set", "ENAset")))
})

test_that("missing columns throw an informative error", {
  data(RS.data)
  testthat::expect_error(
    ena.ccd.window(
      RS.data,
      codeNames = c("NonExistentCode"),
      conversation_cols = c("Condition", "GroupName")
    ),
    "The following columns were not found"
  )

  testthat::expect_error(
    ena.ccd.window(
      RS.data,
      codeNames = c("Data"),
      conversation_cols = c("NonExistentConvo")
    ),
    "The following columns were not found"
  )
})

test_that("short conversations return 1 with a warning", {
  tiny_df <- data.frame(
    Convo = rep(c("C1", "C2"), each = 4),
    A = c(1, 0, 1, 0, 0, 1, 0, 1),
    B = c(0, 1, 0, 1, 1, 0, 1, 0)
  )

  testthat::expect_warning(
    w <- ena.ccd.window(tiny_df, codeNames = c("A", "B"), conversation_cols = "Convo", min_overlap = 10),
    "min_overlap"
  )
  testthat::expect_equal(w, 1L)
})

test_that("logical and factor code columns are properly coerced to numeric", {
  data(RS.data)
  df <- RS.data
  df$Data <- as.logical(df$Data)
  df$Technical.Constraints <- as.factor(df$Technical.Constraints)

  codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
                 "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")

  testthat::expect_no_error({
    w <- ena.ccd.window(df, codeNames = codeNames, conversation_cols = c("Condition", "GroupName"))
  })
  testthat::expect_equal(w, 6L)
})

test_that("print and plot methods execute without error", {
  data(RS.data)
  codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
                 "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")

  res <- ena.ccd(RS.data, codeNames = codeNames, conversation_cols = c("Condition", "GroupName"), max_window = 10)

  testthat::expect_output(print(res), "ENA Cross-Covariance Decay")

  pdf(NULL)
  testthat::expect_no_error(plot(res))
  dev.off()
})
