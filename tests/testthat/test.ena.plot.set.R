suppressMessages(library(rENA, quietly = F, verbose = F))
context("Test plotting sets")

data(RS.data)
codenames <- c("Data", "Technical.Constraints", "Performance.Parameters",
  "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration");

test_that("Create a plot object", {
  accum <- ena.accumulate.data.file(
    RS.data, units.by = c("UserName","Condition"),
    conversations.by = c("ActivityNumber","GroupName"),
    codes = codenames
  );
  set <- ena.make.set(accum)

  newplot <- plot(set)

  testthat::expect_is(newplot, "ena.set")
  testthat::expect_is(newplot$model$plot, "ENAplot")
})

test_that("Plot all points", {
  accum <- ena.accumulate.data.file(
    RS.data, units.by = c("UserName", "Condition"),
    conversations.by = c("ActivityNumber", "GroupName"),
    codes = codenames
  );
  newset <- ena.make.set(accum)

  newplot <- plot(newset) %>% add_points()

  testthat::expect_equal(nrow(newplot$model$plot$plotted$points[[1]]$points), nrow(newset$points))
})

test_that("Plot some points", {
  accum <- ena.accumulate.data.file(
    RS.data, units.by = c("UserName", "Condition"),
    conversations.by = c("ActivityNumber", "GroupName"),
    codes = codenames
  );
  newset <- ena.make.set(accum)

  newplot <- plot(newset) %>%
     add_points(Condition$FirstGame, colors = "blue")

  expected <- nrow(newset$points$Condition$FirstGame)
  observed <- nrow(newplot$model$plot$plotted$points[[1]]$points)
  testthat::expect_equal(observed, expected)

  n_to_plot = 5
  newplot2 <- plot(newset) %>%
                add_points(as.matrix(
                  newset$points$Condition$FirstGame)[1:n_to_plot, ]
                )

  observed <- nrow(newplot2$model$plot$plotted$points[[1]]$points)
  testthat::expect_equal(observed, 5)
})

test_that("Plot some points with mean from list", {
  accum <- ena.accumulate.data.file(
    RS.data, units.by = c("UserName", "Condition"),
    conversations.by = c("ActivityNumber", "GroupName"),
    codes = codenames
  );
  newset <- ena.make.set(accum)

  newplot <- plot(newset) %>%
     add_points(Condition$FirstGame, colors = "blue", mean = list(colors = "red"))

  testthat::expect_equal(
    nrow(newplot$model$plot$plotted$points[[1]]$points),
    nrow(newset$points$Condition$FirstGame)
  )
})

test_that("Plot a group", {
  accum <- rENA:::ena.accumulate.data.file(
    RS.data, units.by = c("UserName", "Condition"),
    conversations.by = c("ActivityNumber", "GroupName"),
    codes = codenames
  );
  newset <- ena.make.set(accum)

  newplot <- plot(newset) %>%
     add_group(Condition$FirstGame, colors = "blue")

  testthat::expect_equal(nrow(newplot$model$plot$plotted$points[[1]]$points), 1)

  noplot = testthat::expect_warning(plot(newset) %>%
                          add_group(Condition$NoGame))
  noplot = testthat::expect_warning(plot(newset) %>%
                          add_group(Condition2$FirstGame))
})

test_that("Plot a network", {
  accum <- rENA:::ena.accumulate.data.file(
    RS.data, units.by = c("UserName", "Condition"),
    conversations.by = c("ActivityNumber", "GroupName"),
    codes = codenames
  );
  newset <- ena.make.set(accum)

  newplot <- plot(newset) %>% add_network(Condition$FirstGame)
  testthat::expect_equal(
    length(newplot$model$plot$plotted$networks[[1]]),
    ncol(newset$rotation$adjacency.key)
  )

  newplot2 <- plot(newset) %>% add_network(with.mean = TRUE)
  testthat::expect_equal(
    length(newplot$model$plot$plotted$networks[[1]]),
    ncol(newset$rotation$adjacency.key)
  )
  testthat::expect_equal(length(newplot2$model$plot$plotted$points), 1)

  newplot3 <- plot(newset) %>%
                add_network(Condition$FirstGame, with.mean = TRUE)
  testthat::expect_equal(
    length(newplot3$model$plot$plotted$networks[[1]]),
    ncol(newset$rotation$adjacency.key)
  )

  wgts <- as.matrix(newset$line.weights$Condition$FirstGame)
  expect_equal(nrow(wgts), 26)
  newplot4 <- plot(newset) %>% add_network(wgts)
  testthat::expect_equal(
    length(newplot4$model$plot$plotted$networks[[1]]),
    ncol(newset$rotation$adjacency.key)
  )

  expect_warning(plot(newset) %>% add_network(wgts, with.mean = T))

  newplot5 <- plot(newset) %>%
              add_network(
                Condition$FirstGame - Condition$SecondGame, with.mean = TRUE
              )
  testthat::expect_equal(length(newplot5$model$plot$plotted$points), 2)
  testthat::expect_equal(
    length(newplot5$model$plot$plotted$networks[[1]]),
    ncol(newset$rotation$adjacency.key)
  )
})

test_that("Plot a Trajectory", {
  accum <- rENA:::ena.accumulate.data.file(
    RS.data, units.by = c("UserName", "Condition"),
    conversations.by = c("ActivityNumber", "GroupName"),
    codes = codenames,
    model = "A"
  );
  newset <- ena.make.set(accum)

  newplot <- plot(newset) %>% add_trajectory("ENA_UNIT")
  testthat::expect_equal(
    nrow(newplot$model$plot$plotted$trajectories[[1]]),
    length(unique(newset$points$ENA_UNIT))
  )

  newplot2 <- plot(newset) %>% add_trajectory()
  testthat::expect_equal(
    nrow(newplot2$model$plot$plotted$trajectories[[1]]),
    length(unique(newset$points$ENA_UNIT))
  )

  newplot3 <- plot(newset) %>% add_trajectory(Condition$FirstGame)
  testthat::expect_equal(
    nrow(newplot3$model$plot$plotted$trajectories[[1]]),
    length(unique(newset$points$Condition$FirstGame$ENA_UNIT))
  )
})
