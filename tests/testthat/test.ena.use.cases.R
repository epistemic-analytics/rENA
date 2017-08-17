suppressMessages(library(rENA, quietly = T, verbose = F))
context("Test Use Cases");


df.file <- system.file("extdata", "rs.data.csv", package="rENA")
#### change to codes specified in doc
codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");

df.accum = ena.accumulate.data.file(
  df.file,
  units.by = c("UserName","Condition"),
  conversations.by = c("Condition","GroupName"),
  codes = codeNames, window.size.back = 4
);

df.set = ena.make.set(df.accum, rotation.by = list(c(FUN = "ena.rotate.by.mean", list("Condition" = c("FirstGame","SecondGame"))),
    c(FUN = "orthogonal.svd")));

df.plot = ena.plot(df.set.lws);

test_that("Case 1: Group Plotting 1", {


  testthat::expect_is(p, "plotly");
})

test_that("Case 2: Individual Plotting", {

  p = ena.plot.

  testthat::expect_is(p, "plotly");
})

test_that("Case 3: Group Plotting 2", {

  p = ena.plot.

  testthat::expect_is(p, "plotly");
})
test_that("Case 4: Stats", {

  p = ena.plot.

  testthat::expect_is(p, "plotly");
})

test_that("Case 5: Code Masking", {

  df.accum = ena.accumulate.data.file(
    df.file,
    units.by = c("UserName","Condition"),
    conversations.by = c("Condition","GroupName"),
    codes = codeNames, window.size.back = 4,
    ###### NEED TO CREATE SPECIFIED MASK
    mask = NULL
  );
  p = ena.plot

  testthat::expect_is(p, "plotly");
})

df.accum = ena.accumulate.data.file(
  df.file,
  units.by = c("UserName","Condition"),
  conversations.by = c("Condition","GroupName"),
  codes = codeNames, window.size.back = 4
);
df.set = ena.make.set(df.accum, rotation.by = list(c(FUN = "ena.rotate.by.mean", list("Condition" = c("FirstGame","SecondGame"))),
                                                   c(FUN = "orthogonal.svd"),
                                                   c(FUN = "pca_c", list("dims" = 2))));
df.plot = ena.plot(df.set);

test_that("Case 6: Other Rotation Functions", {

  p = ena.plot.

  testthat::expect_is(p, "plotly");
})
test_that("Case 7: Bidirectional ENA", {

  p = ena.plot.

  testthat::expect_is(p, "plotly");
})
test_that("Case 8: Expected Value ENA", {

  p = ena.plot.

  testthat::expect_is(p, "plotly");
})
