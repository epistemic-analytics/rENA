suppressMessages(library(rENA, quietly = T, verbose = F))
context("Test making sets");

df.file <- system.file("extdata", "rs.data.csv", package="rENA")
codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");

test_that("Simple data.frame to accumulate and make set", {
  df.accum = ena.accumulate.data(df.file, units.by = c("UserName","Condition"), conversations.by = c("ActivityNumber","GroupName"), code.names = codeNames);

  df.set = ena.make.set(df.accum)
  df.set.lws = ena.make.set(df.accum, position.method = lws.positions.es)

  testthat::expect_equal(
    dim(df.set$data$centered$rotated),
    c(48,2)
  );

  testthat::expect_equal(
    length(attr(df.set$data$centered$rotated, rENA::opts$UNIT_NAMES)[,UserName]),
    48
  );
})

test_that("Simple data.frame to accumulate and make set with Linderoth method(s)", {
  df.accum = ena.accumulate.data(df.file, units.by = c("UserName","Condition"), conversations.by = c("ActivityNumber","GroupName"), code.names = codeNames);

  df.set.lws = ena.make.set(df.accum, position.method = lws.positions)
  df.set.lws.es = ena.make.set(df.accum, position.method = lws.positions.es)

  testthat::expect_equal(
    dim(df.set.lws$data$centered$rotated),
    c(48,2)
  );

  testthat::expect_equal(
    length(attr(df.set.lws$data$centered$rotated, rENA::opts$UNIT_NAMES)[,UserName]),
    48
  );
})


test_that("Make a simple trajectory set", {
  df.accum = ena.accumulate.data(
    df.file, units.by = c("UserName","Condition"), conversations.by = c("ActivityNumber","GroupName"),
    code.names = codeNames,
    trajectory.by = c("ActivityNumber"), trajectory.type = "accumulated"
  );

  df.set.lws = ena.make.set(df.accum, position.method = lws.positions)

  testthat::expect_equal(
    length(attr(df.set.lws$data$centered$rotated, rENA::opts$UNIT_NAMES)[,UserName]),
    517
  );
})
