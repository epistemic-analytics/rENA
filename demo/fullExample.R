codeNames = c("Data","Technical.Constraints","Performance.Parameters","Client.and.Consultant.Requests","Design.Reasoning","Collaboration")
accum = ena.accumulate.data(
  units = RS.data[,c("Condition","UserName")],
  conversation = RS.data[,c("Condition","GroupName")],
  metadata = RS.data[,c("CONFIDENCE.Change","CONFIDENCE.Pre","CONFIDENCE.Post","C.Change")],
  codes = RS.data[,codeNames],
  model = "EndPoint",
  window.size.back = 4
);
set = ena.make.set(
  enadata = accum,
  rotation.by = ena.rotate.by.mean,
  rotation.params = list(FirstGame=accum$meta.data$Condition=="FirstGame", SecondGame=accum$meta.data$Condition=="SecondGame")
);

### Subset rotated points and plot Condition 1 Group Mean
first.game = set$meta.data$Condition == "FirstGame"
first.game.points = set$points[first.game,]

### Subset rotated points and plot Condition 2 Group Mean
second.game = set$meta.data$Condition == "SecondGame"
second.game.points = set$points[second.game,]

ena.conversations(set = set,
  units = c("FirstGame.steven z"), units.by=c("Condition","UserName"),
  conversation.by = c("Condition","GroupName"),
  codes=codeNames,
  window = 4
)

### get mean network plots
first.game.lineweights = set$line.weights[first.game,]
first.game.mean = colMeans(first.game.lineweights)

second.game.lineweights = set$line.weights[second.game,]
second.game.mean = colMeans(second.game.lineweights)

subtracted.network = first.game.mean - second.game.mean

#Plot subtracted network only
plot1 = ena.plot(set)
plot1 = ena.plot.network(plot1, network = subtracted.network)
print(plot1)

#plot means only
plot2 = ena.plot(set)
plot2 = ena.plot.group(plot2, second.game.points, labels = "SecondGame", colors  = "blue", confidence.interval = "box")
plot2 = ena.plot.group(plot2, first.game.points, labels = "FirstGame", colors = "red", confidence.interval = "box")
print(plot2)

#plot both
plot3 = ena.plot(set)
plot3 = ena.plot.network(plot3, network = subtracted.network)
plot3 = ena.plot.group(plot3, first.game.points, labels = "FirstGame", colors = "red", confidence.interval = "box")
plot3 = ena.plot.group(plot3, second.game.points, labels = "SecondGame", colors  = "blue", confidence.interval = "box")
print(plot3)

accum_traj = ena.accumulate.data(
  units = RS.data[,c("UserName","Condition")],
  conversation = RS.data[,c("GroupName","ActivityNumber")],
  metadata = RS.data[,c("CONFIDENCE.Change","CONFIDENCE.Pre","CONFIDENCE.Post","C.Change")],
  codes = RS.data[,codeNames],
  window.size.back = 4,
  model = "A"
)
set_traj = ena.make.set(accum_traj)

plot_traj = ena.plot(set_traj)
plot_traj = ena.plot.network(plot_traj, network = subtracted.network, legend.name="Network", legend.include.edges = T)

dim.by.activity = cbind(
 as.matrix(set_traj$points)[,1],
 set_traj$trajectories$ActivityNumber*.8/14-.4  #scale down to dimension 1
)
plot_traj = ena.plot.trajectory(
  plot_traj,
  points = dim.by.activity,
  names = unique(set_traj$trajectories$UserName),
  by = set_traj$trajectories$UserName
)
print(plot_traj)
