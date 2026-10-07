context("Input validation")

codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
               "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")

accumulate_rs <- function(data, ...) {
  ena.accumulate.data(
    units = data[, c("Condition", "UserName")],
    conversation = data[, c("Condition", "GroupName")],
    codes = data[, codeNames],
    window.size.back = 4, ...
  )
}

test_that("NA in a code column is an error, not an all-zero unit", {
  data(RS.data)
  df <- RS.data
  df$Data[1:50] <- NA
  expect_error(accumulate_rs(df), "missing values \\(NA\\): Data")
})

test_that("non-numeric code columns are an error", {
  data(RS.data)
  df <- RS.data
  df$Collaboration <- as.character(df$Collaboration)
  expect_error(accumulate_rs(df), "must be numeric or logical: Collaboration")
})

test_that("logical code columns are accepted", {
  data(RS.data)
  df <- RS.data
  df$Data <- as.logical(df$Data)
  expect_s3_class(accumulate_rs(df), "ena.set")
})

test_that("metadata with the wrong number of rows is an error, not dropped", {
  data(RS.data)
  expect_error(accumulate_rs(RS.data, metadata = RS.data[1:10, c("CONFIDENCE.Change"), drop = FALSE]),
               "metadata has 10 rows")
  ok <- accumulate_rs(RS.data, metadata = RS.data[, "CONFIDENCE.Change", drop = FALSE])
  expect_true("CONFIDENCE.Change" %in% colnames(ok$meta.data))
})

test_that("ena.ccd.window converts factor codes by label and rejects NA", {
  data(RS.data)
  df <- RS.data
  df$Data <- factor(df$Data)                  # levels "0","1" -> 0/1, not 1/2
  w_factor <- ena.ccd.window(df, codeNames = codeNames, conversation_cols = c("Condition", "GroupName"))
  w_plain  <- ena.ccd.window(RS.data, codeNames = codeNames, conversation_cols = c("Condition", "GroupName"))
  expect_equal(w_factor, w_plain)

  df$Data <- RS.data$Data
  df$Data[3] <- NA
  expect_error(ena.ccd.window(df, codeNames = codeNames, conversation_cols = c("Condition", "GroupName")),
               "missing or non-numeric values: Data")
})
