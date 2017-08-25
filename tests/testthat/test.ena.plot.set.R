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
  conversations.by = c("ActivityNumber"),
  codes = codeNames,
  model = "A"
);
df.set.traj.lws = ena.make.set(df.accum.traj, position.method = lws.positions.es);

test_that("Plot all units in set", {
  p <- ena.plot(df.set.lws) %>% ena.plot.points()

  # testthat::expect_is(p, "plotly");
})

test_that("Plot only some units, sampled from centered data", {
  p.color <- ena.plot(df.set.lws);
  p.color %<>% ena.plot.points(points = sample(df.set.lws$get.data("centered")$ENA_UNIT,10), color = "yellow");
  p.color %<>% ena.plot.points(points = sample(df.set.lws$get.data("centered")$ENA_UNIT,10), color = "green");

  # testthat::expect_is(p, "plotly");
})

test_that("Plot a trajectory set", {
  p.traj <- ena.plot(df.set.traj.lws);

  p.traj %<>% ena.plot.points(
    points = sample(df.set.lws$get.data("centered")$ENA_UNIT,3)
  );

  # testthat::expect_is(p, "plotly");
})

test_that("Plot a trajectory set", {
  p.traj <- ena.plot(df.set.traj.lws);
  p.traj %<>% ena.plot.points(
    points = sample(df.set.lws$get.data("centered")$ENA_UNIT,3)
  );
  p.traj %<>% ena.plot.points(
    points = sample(df.set.lws$get.data("rotated")$ENA_UNIT,3)
  );

  # testthat::expect_is(p, "plotly");
})

test_that("Plot a network", {
  p = ena.plot.set(
    df.set.lws,
    plot.mode="network",
    network.one="brandon f.SecondGame"
  );

  # testthat::expect_is(p, "plotly");
})

test_that("Plot two networks", {
  p = ena.plot.set(
    df.set.lws,
    plot.mode="network",
    network.one="brandon f.SecondGame",
    network.two="arden f.FirstGame"
  );

  # testthat::expect_is(p, "plotly");
})

test_that("Plot a mean trajectory", {
  message("Testing a mean trajectory: not implemented")
})

test_that("Plot a combined plot of units and nodes", {
  message("Test for units+nodes: not implemented")
})




