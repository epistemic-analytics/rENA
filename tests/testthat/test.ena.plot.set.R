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

##### TESTING PLOT.GROUP
group1.points = df.set.lws$points.rotated[df.set.lws$enadata$units$Condition == "FirstGame",]

##### FOR TESTING ALREADY MEANED GROUP
#group.points = colMeans(group.points)
#group.points = data.frame("V1" = group.points[1], "V2" = group.points[2])

df.plot <- ena.plot(df.set.lws);
df.plot = ena.plot.points(df.plot, points = data.frame(group1.points));
df.plot = ena.plot.group(df.plot, group1.points, color = "blue", label = "First Game Mean", show.confidence.interval = T);


#####

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
  p.color = ena.plot.points(p.color, points = df.set.lws$get.data("centered")$ENA_UNIT, color = "yellow");
  p.color = ena.plot.points(p.color, points = df.set.lws$get.data("centered")$ENA_UNIT, color = "green");

  # testthat::expect_is(p, "plotly");
})

test_that("Plot a trajectory set", {
  p.traj <- ena.plot(df.set.traj.lws);

  p.traj = ena.plot.points(
    enaplot = p.traj,
    points = df.set.traj.lws$get.data("centered")$ENA_UNIT
  );

  # testthat::expect_is(p, "plotly");
})

test_that("Plot a trajectory set", {
  p.traj <- ena.plot(df.set.traj.lws);
  p.traj = ena.plot.points(
    p.traj,
    points = df.set.traj.lws$get.data("centered")$ENA_UNIT
  );
  p.traj = ena.plot.points(
    p.traj,
    points = df.set.traj.lws$get.data("rotated")$ENA_UNIT
  );

  # testthat::expect_is(p, "plotly");
})

# test_that("Plot a network", {
  # p = ena.plot.set(
  #   df.set.lws,
  #   plot.mode="network",
  #   network.one="brandon f.SecondGame"
  # );

  # testthat::expect_is(p, "plotly");
# })

# test_that("Plot two networks", {
#   p = ena.plot.set(
#     df.set.lws,
#     plot.mode="network",
#     network.one="brandon f.SecondGame",
#     network.two="arden f.FirstGame"
#   );
#
#   # testthat::expect_is(p, "plotly");
# })

test_that("Plot a mean trajectory", {
  message("Testing a mean trajectory: not implemented")
})

test_that("Plot a combined plot of units and nodes", {
  message("Test for units+nodes: not implemented")
})




