suppressMessages(library(rENA, quietly = T, verbose = F))
context("Test making sets");

df.file <- system.file("extdata", "rs.data.csv", package="rENA")
codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");

test_that("Simple data.frame to accumulate and make set", {
  df.accum = ena.accumulate.data.file(df.file, units.by = c("UserName","Condition"), conversations.by = c("ActivityNumber","GroupName"), codes = codeNames);

  df.set = ena.make.set(df.accum, node.position.method = egr.positions)
  df.set.lws = ena.make.set(df.accum, node.position.method = lws.positions.es)

  ###NEW TESTs - length of unit.names and codes equal to known number of unit names and codes
  testthat::expect_equal(length(df.set.lws$unit.names), 48);

  testthat::expect_equal(length(df.set.lws$codes), 16);

  testthat::expect_equal(
    dim(df.set$points.rotated),
    c(48,2)
  );

  testthat::expect_equal(
    length(attr(df.set$points.rotated, rENA::opts$UNIT_NAMES)[,UserName]),
    48
  );

  df.set.json = ena.make.set(df.accum, node.position.method = lws.positions, output = "json")
  testthat::expect_is(df.set.json, "list")
})

test_that("Simple data.frame to accumulate and make set with Linderoth method(s)", {
  df.accum = ena.accumulate.data.file(df.file, units.by = c("UserName","Condition"), conversations.by = c("ActivityNumber","GroupName"), codes = codeNames);

  df.set.lws = ena.make.set(df.accum, position.method = lws.positions)
  df.set.lws.es = ena.make.set(df.accum, position.method = lws.positions.es)

  testthat::expect_equal(
    dim(df.set.lws$points.rotated),
    c(48,2)
  );

  testthat::expect_equal(
    length(attr(df.set.lws$points.rotated, rENA::opts$UNIT_NAMES)[,UserName]),
    48
  );
})


test_that("Make a simple trajectory set", {
  df.accum = ena.accumulate.data.file(
    df.file, units.by = c("UserName","Condition"), conversations.by = c("ActivityNumber","GroupName"),
    codes = codeNames,
    model = "AccumulatedTrajectory",
    trajectory.by = c("ActivityNumber")#, trajectory.type = "accumulated"
  );

  df.set.lws = ena.make.set(df.accum, node.position.method = lws.positions)

  testthat::expect_equal(
    length(attr(df.set.lws$points.rotated, rENA::opts$UNIT_NAMES)[,UserName]),
    517
  );
})
