suppressMessages(library(rENA, quietly = T, verbose = F))
context("Test making sets");

test_that("Simple data.frame to accumulate and make set", {
  codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");

  df.accum = ena.accumulate.data("./inst/extdata/rs.data.small.csv", units.by = c("UserName","Condition"), conversations.by = c("ActivityNumber","GroupName"), code.names = codeNames);

  df.set = ena.make.set(df.accum)

  expect_equal(dim(df.set$data$centered$rotated), c(16,2));
  expect_equal(length(attr(df.set$data$centered$rotated, rENA::UNIT_NAMES)[,UserName]), 16);
})
