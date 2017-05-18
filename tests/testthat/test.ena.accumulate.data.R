suppressMessages(library(rENA, quietly = T, verbose = F))
context("Test accumulating data");

test_that("Simple data.frame to accumulate", {
  fake.codes.len = 10;
  fake.codes <- function(x) sample(0:1,fake.codes.len, replace=T)

  code.names = paste("Codes",LETTERS[1:fake.codes.len],sep="-");

  df = data.frame(
    Name=c("J","Z"),
    Day=c(1,1,1,1,1,1,2,2,2,2,2,2),
    c1=c(1,1,1,1,1,0,0,1,1,0,0,1),
    c2=c(1,1,1,0,0,1,0,1,0,1,0,0),
    c3=c(0,0,1,0,1,0,1,0,0,0,1,0),
    c4=c(1,1,1,0,0,1,0,1,0,1,0,0)
  );

  df.accum = ena.accumulate.data(df, units.by = c("Name"), conversations.by = c("Day"), code.names = c("c1","c2","c3"));

  expect_true(all(
    as.matrix(df.accum$data.units.summed[, attr(df.accum$data.units.summed,"adjacency.codes"), with=F])
      ==
    matrix(c(2,2,2,0,1,0), nrow=length(unique(df.accum$get("units"))))
  ));
})

test_that("Simple forwarded metadata", {
  fake.codes.len = 10;
  fake.codes <- function(x) sample(0:1,fake.codes.len, replace=T)

  code.names = paste("Codes",LETTERS[1:fake.codes.len],sep="-");

  df = data.frame(
    Name=c("J","Z"),
    Day=c(1,1,1,1,1,1,2,2,2,2,2,2),
    c1=c(1,1,1,1,1,0,0,1,1,0,0,1),
    c2=c(1,1,1,0,0,1,0,1,0,1,0,0),
    c3=c(0,0,1,0,1,0,1,0,0,0,1,0),
    m1=c(1,2),
    m2=c(1,2,3,4)
  );

  df.accum = ena.accumulate.data(df, units.by = c("Name"), conversations.by = c("Day"), code.names = c("c1","c2","c3"));

  expect_true("m1" %in% colnames(df.accum$data.units.summed.meta));
})
