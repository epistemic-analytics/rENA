suppressMessages(library(rENA, quietly = F, verbose = F))
context("Test plotting sets")

data(RS.data)
codenames <- c("Data", "Technical.Constraints", "Performance.Parameters",
  "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration");

title = "ENA Plot"
dimension.labels = c("","")
font.size = 10
font.color = "#000000"
font.family = "Arial"
scale.to = "network"

accum <- rENA:::ena.accumulate.data.file(
  RS.data, units.by = c("UserName", "Condition"),
  conversations.by = c("ActivityNumber", "GroupName"),
  codes = codenames, as.list = FALSE
);
enaset <- ena.make.set(accum, as.list = FALSE)
test_that("Test for ENAplot", {


  testthat::expect_warning(ENAplot$new(enaset,
                     title,
                     dimension.labels,
                     font.size,
                     font.color,
                     font.family,
                     scale.to = scale.to
                   ))
})

test_that("Test extra args", {

  accum <- rENA:::ena.accumulate.data.file(
    RS.data, units.by = c("UserName", "Condition"),
    conversations.by = c("ActivityNumber", "GroupName"),
    codes = codenames
  );
  set <- ena.make.set(accum)
  newplot <- ENAplot$new(set,
                     title,
                     dimension.labels,
                     font.size,
                     font.color,
                     font.family,
                     multiplier = 2.5,
                     point.size = 20,
                     scale.to = "points"
                     ,ticks = list(color = "red")
                   )
  testthat::expect_equal(newplot$get("multiplier"), 2.5)
  testthat::expect_equal(newplot$point$size, 20)
  testthat::expect_equal(newplot$plot$x$layoutAttrs[[1]]$xaxis$tickcolor, "red")

  newplot <- ENAplot$new(set,
                     title,
                     dimension.labels,
                     font.size,
                     font.color,
                     font.family,
                     scale.to = c(1, 25)
                   )
  testthat::expect_equal(newplot$plot$x$layoutAttrs[[1]]$xaxis$range[2], 25)

  newplot <- ENAplot$new(set,
                     title,
                     dimension.labels,
                     font.size,
                     font.color,
                     font.family,
                     scale.to = list(
                       x = c(-100, 100),
                       y = c(-200, 200)
                     )
                   )
  testthat::expect_equal(newplot$plot$x$layoutAttrs[[1]]$xaxis$range[2], 100)
  testthat::expect_equal(newplot$plot$x$layoutAttrs[[1]]$yaxis$range[2], 200)

  newplot <- ENAplot$new(set,
                     title,
                     dimension.labels,
                     font.size,
                     font.color,
                     font.family,
                     scale.to = list(
                       x = c(-100, 100)
                     )
                   )
  testthat::expect_equal(newplot$plot$x$layoutAttrs[[1]]$xaxis$range[2], 100)
  testthat::expect_lte(newplot$plot$x$layoutAttrs[[1]]$yaxis$range[2], 1)

  newplot <- ENAplot$new(set,
                     title,
                     dimension.labels,
                     font.size,
                     font.color,
                     font.family,
                     scale.to = list(
                       y = c(-200, 200)
                     )
                   )
  testthat::expect_lte(newplot$plot$x$layoutAttrs[[1]]$xaxis$range[2], 1)
  testthat::expect_equal(newplot$plot$x$layoutAttrs[[1]]$yaxis$range[2], 200)
})
