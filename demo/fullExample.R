data(RS.data)

codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
               "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")

### Accumulate and build an ENA set
accum <- ena.accumulate.data(
  units = RS.data[, c("Condition", "UserName")],
  conversation = RS.data[, c("Condition", "GroupName")],
  metadata = RS.data[, c("CONFIDENCE.Change", "CONFIDENCE.Pre", "CONFIDENCE.Post", "C.Change")],
  codes = RS.data[, codeNames],
  window.size.back = 4
)
set <- ena.make.set(accum)

### Group means and the subtracted network
first.game <- set$meta.data$Condition == "FirstGame"
second.game <- set$meta.data$Condition == "SecondGame"
subtracted.network <- colMeans(set$line.weights[first.game, ]) -
  colMeans(set$line.weights[second.game, ])

### Plot the subtracted network with both group means
plot(set) |>
  add_network(subtracted.network) |>
  add_points(Condition$FirstGame, mean = TRUE, colors = "red") |>
  add_points(Condition$SecondGame, mean = TRUE, colors = "blue")

### The same comparison, written with the plot helpers
plot(set) |>
  add_network(Condition$FirstGame - Condition$SecondGame) |>
  add_group(Condition$FirstGame) |>
  add_group(Condition$SecondGame)

### Trajectories over activities
traj <- ena.accumulate.data(
  units = RS.data[, c("UserName", "Condition")],
  conversation = RS.data[, c("GroupName", "ActivityNumber")],
  codes = RS.data[, codeNames],
  window.size.back = 4,
  model = "A"
)
plot(ena.make.set(traj)) |>
  add_trajectory(Condition$FirstGame)
