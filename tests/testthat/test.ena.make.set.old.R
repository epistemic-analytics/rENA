suppressMessages(library(rENA, quietly = T, verbose = F))
context("Test making R6 sets");

codeNames = c('Data','Technical.Constraints','Performance.Parameters','Client.and.Consultant.Requests','Design.Reasoning','Collaboration');

test_that("Accumulate returns an R6", {
  data(RS.data)

  df.file <- RS.data

  df.accum = suppressWarnings(
    ena.accumulate.data.file(
      df.file, units.by = c("UserName","Condition"), 
      conversations.by = c("ActivityNumber","GroupName"), codes = codeNames, as.list = FALSE)
  )

  testthat::expect_is(df.accum, "ENAdata", "Accumulation with as.list = FALSE did not return ENAdata")
})

test_that("Make.set returns an R6", {
  data(RS.data)

  df.file <- RS.data

  df.accum = suppressWarnings(
    ena.accumulate.data.file(
      df.file, units.by = c("UserName","Condition"), 
      conversations.by = c("ActivityNumber","GroupName"), codes = codeNames, as.list = FALSE)
  )

  df.set = suppressWarnings(
    ena.make.set(df.accum, as.list = FALSE)
  )

  testthat::expect_is(df.set, "ENAset", "Set with as.list = FALSE did not return ENAset")
})

test_that("Old sets are the same as the new ones", {
  data(RS.data)

  units.by = c("UserName","Condition")
  conv.by = c("Condition","GroupName")

  df.accum = suppressWarnings(
    ena.accumulate.data.file(
      RS.data, units.by = units.by, 
      conversations.by = conv.by, codes = codeNames, as.list = FALSE, window.size.back = 4)
  )

  df.set = suppressWarnings(
    ena.make.set(df.accum, as.list = FALSE)
  )

  new.set = ena.accumulate.data(
          units = RS.data[, units.by],
          conversation = RS.data[, conv.by],
          metadata = RS.data[, codeNames],
          codes = RS.data[,codes],
          model = "EndPoint",
          window.size.back = 4
        ) %>%
          ena.make.set()

  testthat::expect_equivalent(df.set$points.rotated, as.matrix(new.set$points))
  testthat::expect_equivalent(df.set$line.weights, as.matrix(new.set$line.weights))
})