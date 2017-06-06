suppressMessages(library(rENA, quietly = T, verbose = F))
context("Test plotting sets");


df.file <- system.file("extdata", "rs.data.csv", package="rENA")
codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");

test_that("Plot a regular set.", {
  df.accum = ena.accumulate.data(df.file, units.by = c("UserName","Condition"), conversations.by = c("ActivityNumber","GroupName"), code.names = codeNames);

  df.set = ena.make.set(df.accum, position.method = lws.positions.es)
  p = ena.plot.set(df.set, plot.mode="units", unit.group = "Condition", unit.group.size = 2);

  testthat::expect_is(p, "plotly");
})

test_that("Plot a trajectory set", {
  df.accum = ena.accumulate.data(
    df.file, units.by = c("UserName","Condition"), conversations.by = c("ActivityNumber","GroupName"),
    code.names = codeNames,
    trajectory.by = c("ActivityNumber"), trajectory.type = "accumulated"
  );

  df.set.lws = ena.make.set(df.accum, position.method = lws.positions)
  p = ena.plot.set(df.set.lws, plot.mode="units", unit.group = "Condition", unit.group.size = 2, unit.trajectory.by = c("ActivityNumber"));

  testthat::expect_is(p, "plotly");
})

test_that("Plot some nodes", {
  df.accum = ena.accumulate.data(df.file, units.by = c("UserName","Condition"), conversations.by = c("ActivityNumber","GroupName"), code.names = codeNames);
  df.set = ena.make.set(df.accum)
  #df.set.lws = ena.make.set(df.accum, position.method = rENA::lws.positions)
  p = ena.plot.set(df.set, plot.mode="network", network.one="brandon f.SecondGame");
  testthat::expect_is(p, "plotly");
})
test_that("Plot two networks", {
  df.accum = ena.accumulate.data(df.file, units.by = c("UserName","Condition"), conversations.by = c("ActivityNumber","GroupName"), code.names = codeNames);
  df.set = ena.make.set(df.accum)
  df.set.lws = ena.make.set(df.accum, position.method = lws.positions)
  p = ena.plot.set(df.set.lws, plot.mode="network", network.one="brandon f.SecondGame", network.two="arden f.FirstGame");
  testthat::expect_is(p, "plotly");
})
