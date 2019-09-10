suppressMessages(library(rENA, quietly = T, verbose = F))
context("Test connection matrices");

library(magrittr)

data(RS.data)
units <- c("UserName", "Condition")
conversation <- c("ActivityNumber", "GroupName")
codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
            "Client.and.Consultant.Requests", "Design.Reasoning",
            "Collaboration")

set_end <- RS.data %>%
  ena(
    units = units,
    conversation = conversation,
    codes = codes,
    window.size.back = 4
  )

test_that("return square matrix", {
  connections <- connection.matrix(set_end)

  testthat::expect_equal(ncol(connections[[1]]), nrow(connections[[1]]))
})

test_that("return all units", {
  connections <- connection.matrix(set_end)
  testthat::expect_equal(length(connections), length(set_end$model$unit.labels))
  testthat::expect_equal(names(connections), set_end$model$unit.labels)
})

test_that("return single unit", {
  connections <- connection.matrix(set_end$connection.counts$ENA_UNIT$`steven z.FirstGame`)

  testthat::expect_is(connections, "matrix")
  testthat::expect_equal(nrow(connections), ncol(connections))
})
