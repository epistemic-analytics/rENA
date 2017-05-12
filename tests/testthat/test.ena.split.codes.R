suppressMessages(library(rENA, quietly = T, verbose = F))
context("Split concatenated code column");

test_that("Code column splits on file", {
  fileName = "../../inst/extdata/test-bad-code-col.csv";
  file = read.csv(fileName);
  split = ena.split.codes(fileName, split.columns="Codes");

  expect_is(split, "data.frame");
  expect_gt(length(colnames(split)), length(colnames(file)));
})


test_that("Code column splits on data.frame", {
  fake.codes.len = 10;
  fake.codes <- function() paste(sample(10,fake.codes.len), collapse=",")

  code.names = paste("Codes",LETTERS[1:fake.codes.len],sep="-");

  df = data.frame(Name=c("Jon","Zeke"),Codes=c(fake.codes(),fake.codes()))
  split = ena.split.codes(df, split.columns="Codes", code.names = code.names);

  expect_is(split, "data.frame");
  expect_gt(length(colnames(split)), length(colnames(file)));

  expect_equal(names(split)[names(split) != "Name"], code.names);
})

