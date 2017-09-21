suppressMessages(library(rENA, quietly = T, verbose = F))
context("Test Use Cases");

fileName = system.file("extdata","rs.data.csv", package = "rENA")
file = read.csv(fileName);
codeNames = c("Tradeoffs", "Performance.Parameters", "Constraints.and.Requests", "Collaboration", "Data");

accum = ena.accumulate.data(
  units = file[,c("UserName","Condition")],
  conversation = file[,c("Condition","GroupName")],
  codes = file[,codeNames],
  window.size.back = 4
);

set = ena.make.set(
  enadata = accum,
  rotation.by = ena.rotate.by.mean,
  rotation.params = list(accum$metadata$Condition=="FirstGame", accum$metadata$Condition=="SecondGame")
)

test_that("Case 1: Group Plotting 1", {
  ### GROUP PLOTTING VERSION 1

  unitNames = set$enadata$units

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

  plot = ena.plot(set) %>%
    ena.plot.points(first.game.mean, labels = "Condition = FirstGame", colors = "red", shape = "square", confidence.interval.values = first.game.ci, confidence.interval = "crosshair") %>%
    ena.plot.points(second.game.mean, labels = "Condition = SecondGame", colors  = "blue", shape = "square", confidence.interval.values = second.game.ci, confidence.interval = "crosshair")

   testthat::expect_is(p, c("ENAplot", "R6"));

   ### GROUP PLOTTING VERSION 2

   unitNames = set$enadata$units

   ### Subset rotated points for Condition 1
   first.game = unitNames$Condition == "FirstGame"
   first.game.points = set$points.rotated[first.game,]

   ### Subset rotated points for Condition 2
   second.game = unitNames$Condition == "SecondGame"
   second.game.points = set$points.rotated[second.game,]

   plot = ena.plot(set) %>%
     ena.plot.group(first.game.points, labels = "Condition = FirstGame", colors = "red", confidence.interval = "crosshair") %>%
     ena.plot.group(second.game.points, labels = "Condition = SecondGame", colors  = "blue", confidence.interval = "crosshair")

   ### END V2

   ### Subset edge weights and plot Condition 1 Mean Network
   first.game.lineweights = set$line.weights[first.game,]
   first.game.mean = colMeans(first.game.lineweights)
   plot %>% ena.plot.network(network = first.game.mean)

   ### Subset edge weights and plot Condition 2 Mean Network
   second.game.lineweights = set$line.weights[second.game,]
   second.game.mean = colMeans(second.game.lineweights)
   plot %>% ena.plot.network(network = second.game.mean)

   ### Subset Plot subtracted mean networks
   subtracted.network = first.game.mean - second.game.mean
   plot %>% ena.plot.network(network = subtracted.network, color = c(pos = "red", neg = "blue") )

   testthat::expect_is(plot, c("ENAplot", "R6"));
})

test_that("Case 2: Individual Plotting", {

  first.game = unitNames$Condition == "FirstGame"
  first.game.points = set$points.rotated[first.game,]
  plot %<>% ena.plot.points(points = first.game.points)

  user.akashv.rows = which(set$units$UserName == "akashv")
  user.akashv = set$line.weights[user.akashv.rows,]
  plot %<>% ena.plot.network(network = this.network)

  testthat::expect_is(plot, c("ENAplot", "R6"));
})

test_that("Case 3: Group Plotting 2", {

  groups = ena.group(set, by = set$enadata$metadata$C.Change, method="mean")

  ####OR TRY THIS WAY####
  groups = ena.group(set, by = (set$enadata$metadata$C.Change=="Pos.Change"), method="mean") #Test to make sure this returns only 1 group

  plot %<>% ena.plot.points(points = groups$points[groups$group.name=="Pos.Change",], labels = "Positive Confidence Change", shape = "square")

  plot %<>% ena.plot.points(points = groups$points[groups$points=="Neg.Change",], labels = "Negative Confidence Change", shape = "square")

  testthat::expect_is(plot, c("ENAplot", "R6"))
})

test_that("Case 4: Stats", {

  unitNames = set$enadata$units
  first.game = unitNames$Condition == "FirstGame"
  first.game.points = set$points.rotated[first.game,]
  second.game = unitNames$Condition == "SecondGame"
  second.game.points = set$points.rotated[second.game,]

  t.test(first.game.points[,1], second.game.points[,1])

  data = cbind(conf.change = set$enadata$metadata$CONFIDENCE.Change,
               dim1 = set$points.rotated[,1])

  lm(conf.change ~ dim1, data.frame(data))

})

test_that("Case 5: Code Masking", {
  ### generate mask matrix
  mask = matrix(1, nrow=length(set$codes), ncol=length(set$codes), dimnames=list(set$codes,set$codes))


  mask["Tradeoffs", "Collaboration"] = 0
  mask["Performance.Parameters", "Collaboration"] = 0

  ###accumulate data using mask
  accum = ena.accumulate.data.file(
    units = file[,c("UserName","Condition")],
    conversation = file[,c("Condition","GroupName")],
    codes = file[,codeNames],
    window.size.back = 4,
    mask = mask
  );

})


test_that("Case 6: Other Rotation Functions", {

  set = ena.make.set(
    accum,
    rotation.by = "ena.svd",
    rotation.params = NULL
  );

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
