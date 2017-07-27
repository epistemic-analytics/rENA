suppressMessages(library(rENA, quietly = T, verbose = F))
context("Test plotting sets");


df.file <- system.file("extdata", "rs.data.csv", package="rENA")
codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");

df.accum = ena.accumulate.data.file(
  df.file,
  units.by = c("UserName","Condition"),
  conversations.by = c("ActivityNumber","GroupName"),
  codes = codeNames, window.size.back = 4
);

df.set.lws = ena.make.set(df.accum, position.method = lws.positions.es);

df.accum.traj = ena.accumulate.data.file(
  df.file,
  units.by = c("UserName","Condition"),
  conversations.by = c("ActivityNumber","GroupName"),
  codes = codeNames,
  trajectory.by = c("ActivityNumber")
  #trajectory.type = "accumulated"
);
df.set.traj.lws = ena.make.set(df.accum.traj, position.method = lws.positions.es);

test_that("Plot all units in set", {
  p = ena.plot.set(
    df.set.lws,
    plot.mode="units",
    unit.group = "Condition",
    unit.group.size = 2
  );

  testthat::expect_is(p, "plotly");
})

test_that("Plot all units without group", {
  p = ena.plot.set(
    df.set.lws,
    plot.mode="units"
  );

  testthat::expect_is(p, "plotly");
})

test_that("Plot only some units without a group", {
  p = ena.plot.set(
    df.set.lws,
    plot.mode="units",
    units = sample(df.set.lws$get.data("centered")$ENA_UNIT,10)
  );

  p.colored = ena.plot.set(
    df.set.lws,
    plot.mode="units",
    units = sample(df.set.lws$get.data("centered")$ENA_UNIT,10),
    unit.colors = I("red")
  );

  testthat::expect_is(p, "plotly");
})

test_that("Plot a trajectory set", {
  p = ena.plot.set(
    df.set.traj.lws,
    plot.mode="units",
    units = sample(df.set.lws$get.data("centered")$ENA_UNIT,3),
    unit.group = "Condition",
    unit.group.size = 2,
    unit.trajectory.by = c("ActivityNumber")
  );

  testthat::expect_is(p, "plotly");
})

test_that("Plot a network", {
  p = ena.plot.set(
    df.set.lws,
    plot.mode="network",
    network.one="brandon f.SecondGame"
  );

  testthat::expect_is(p, "plotly");
})

test_that("Plot two networks", {
  p = ena.plot.set(
    df.set.lws,
    plot.mode="network",
    network.one="brandon f.SecondGame",
    network.two="arden f.FirstGame"
  );

  testthat::expect_is(p, "plotly");
})

test_that("Plot a mean trajectory", {
  message("Testing a mean trajectory: not implemented")
})

test_that("Plot a combined plot of units and nodes", {
  message("Test for units+nodes: not implemented")
})




