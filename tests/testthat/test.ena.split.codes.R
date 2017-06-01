suppressMessages(library(rENA, quietly = T, verbose = F))
context("Split concatenated code column");


test_that("Code column with character delimited codes", {
  file <- system.file("extdata", "test-bad-code-col-2.csv", package="rENA");
  split = ena.split.codes(file, split.columns="Codes");

  testthat::expect_is(split, "data.frame");
  testthat::expect_gt(length(colnames(split)), length(colnames(file)));
})

# test_that("Code column splits on data.frame", {
#   fake.codes.len = 10;
#   fake.codes <- function() paste(sample(10,fake.codes.len), collapse=",")
#
#   code.names = paste("Codes",LETTERS[1:fake.codes.len],sep="-");
#
#   df = data.frame(Name=c("Jon","Zeke"),Codes=c(fake.codes(),fake.codes()))
#   split = ena.split.codes(df, split.columns="Codes", code.names = code.names);
#
#   expect_is(split, "data.frame");
#   expect_gt(length(colnames(split)), length(colnames(file)));
#
#   expect_equal(names(split)[names(split) != "Name"], code.names);
# })

