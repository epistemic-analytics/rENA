suppressMessages(library(rENA, quietly = T, verbose = F))
context("Test Use Cases");

fileName = system.file("extdata","rs.data.csv", package = "rENA")
file = read.csv(fileName);
# codeNames = c("Tradeoffs", "Performance.Parameters", "Constraints.and.Requests", "Collaboration", "Data");
codeNames = c('Data','Technical.Constraints','Performance.Parameters','Client.and.Consultant.Requests','Design.Reasoning'); #,'Collaboration');

accum = ena.accumulate.data(
  units = file[,c("UserName","Condition")],
  conversation = file[,c("Condition","GroupName")],
  metadata = file[,c("CONFIDENCE.Change","CONFIDENCE.Pre","CONFIDENCE.Post","C.Change")],
  codes = file[,codeNames],
  window.size.back = 4
);
set = ena.make.set(
  enadata = accum,
  rotation.by = ena.rotate.by.mean,
  rotation.params = list(accum$metadata$Condition=="FirstGame", accum$metadata$Condition=="SecondGame")
)
unitNames = set$enadata$units

test_that("Case 1: Group Plotting 1", {
    ### Subset rotated points and plot Condition 1 Group Mean
    first.game = unitNames$Condition == "FirstGame"
    first.game.points = set$points.rotated[first.game,]

    ### Subset rotated points and plot Condition 2 Group Mean
    second.game = unitNames$Condition == "SecondGame"
    second.game.points = set$points.rotated[second.game,]

    first.game.mean = colMeans( first.game.points )
    second.game.mean = colMeans( second.game.points )

    first.game.ci = t.test(first.game.points, conf.level = 0.95)$conf.int
    second.game.ci = t.test(second.game.points, conf.level = 0.95)$conf.int

  ### GROUP PLOTTING VERSION 1
    plot = ena.plot(set) %>%
      ena.plot.points(
        first.game.mean, labels="FirstGame", colors = "red", shape="square", confidence.interval.values=first.game.ci, confidence.interval = "crosshair") %>%
      ena.plot.points(second.game.mean, labels = "SecondGame", colors  = "blue", shape="square", confidence.interval.values=second.game.ci, confidence.interval = "crosshair");

    testthat::expect_is(plot, c("ENAplot", "R6"));

  ### GROUP PLOTTING VERSION 2
    plot2 = ena.plot(set) %>%
     ena.plot.group(first.game.points, labels = "FirstGame", colors = "red", confidence.interval = "crosshair") %>%
     ena.plot.group(second.game.points, labels = "SecondGame", colors  = "blue", confidence.interval = "crosshair");

    testthat::expect_is(plot2, c("ENAplot", "R6"));
  ### END V2

   ### Subset edge weights and plot Condition 1 Mean Network
   first.game.lineweights = set$line.weights[first.game,]
   first.game.mean = colMeans(first.game.lineweights)
   plot.network.1 = ena.plot(set) %>% ena.plot.network(network = first.game.mean)

   ### Subset edge weights and plot Condition 2 Mean Network
   second.game.lineweights = set$line.weights[second.game,]
   second.game.mean = colMeans(second.game.lineweights)
   plot.network.2 = ena.plot(set) %>% ena.plot.network(network = second.game.mean, colors = c("blue"))

   ### Subset Plot subtracted mean networks
   subtracted.network = first.game.mean - second.game.mean
   plot.network.sub = ena.plot(set) %>% ena.plot.network(network = subtracted.network)

   testthat::expect_is(plot, c("ENAplot", "R6"));
})

test_that("Case 2: Individual Plotting", {
  first.game = unitNames$Condition == "FirstGame"
  first.game.points = set$points.rotated[first.game,]
  plot.firstgame.points = ena.plot(set) %>% ena.plot.points(points = first.game.points)

  user.akashv.rows = set$enadata$units$UserName == "akash v"
  user.akashv = set$line.weights[user.akashv.rows,]
  user.akashv.network = ena.plot(set) %>% ena.plot.network(network = user.akashv)

  testthat::expect_is(user.akashv.network, c("ENAplot", "R6"));
})

test_that("Case 3: Group Plotting 2", {
  groups = ena.group(set, by=set$enadata$metadata$C.Change, method="mean")

  ####OR TRY THIS WAY####
  groups.2 = ena.group(set, by=set$enadata$metadata$C.Change=="Pos.Change", method="mean") #Test to make sure this returns only 1 group

  plot.confidence.change = ena.plot(set) %>%
                            ena.plot.points(points = groups$points[groups$names=="Pos.Change",], labels = "Positive Confidence Change", shape = "square", colors="red")%>%
                            ena.plot.points(points = groups$points[groups$names=="Neg.Change",], labels = "Negative Confidence Change", shape = "square", colors="blue")

  # testthat::expect_is(plot, c("ENAplot", "R6"))
})

test_that("Case 4: Stats", {
  unitNames = set$enadata$units
  first.game = unitNames$Condition == "FirstGame"
  first.game.points = set$points.rotated[first.game,]
  second.game = unitNames$Condition == "SecondGame"
  second.game.points = set$points.rotated[second.game,]

  t.test(first.game.points[,1], second.game.points[,1])

  data = data.frame("conf.change"=set$enadata$metadata$CONFIDENCE.Change, dim1 = set$points.rotated[,1])

  # lm(conf.change ~ dim1, data)
})

test_that("Case 5: Code Masking", {
  ### generate mask matrix
  mask = matrix(1, nrow=length(set$codes), ncol=length(set$codes), dimnames=list(set$codes,set$codes))
  mask["Data", "Client.and.Consultant.Requests"] = 0
  mask["Technical.Constraints", "Design.Reasoning"] = 0

  ###accumulate data using mask
  accum = ena.accumulate.data(
    units = file[,c("UserName","Condition")],
    conversation = file[,c("Condition","GroupName")],
    codes = file[,codeNames],
    window.size.back = 4,
    mask = mask
  );

  testthat::expect_true(all(accum$adjacency.vectors[,4] == 0))
  testthat::expect_true(all(accum$adjacency.vectors[,8] == 0))
})


test_that("Case 6: Other Rotation Functions", {

  set.new = ena.make.set(
    accum,
    rotation.by = "ena.svd",
    rotation.params = NULL
  );

  testthat::expect_false(identical(set.new$points.rotated, set$points.rotated))
})

test_that("Case 7: Bidirectional ENA", {

  # p = ena.plot.
  #
  # testthat::expect_is(p, "plotly");
})

test_that("Case 8: Expected Value ENA", {

  # p = ena.plot.
  #
  # testthat::expect_is(p, "plotly");
})
