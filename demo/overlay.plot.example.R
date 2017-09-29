file <- read.csv(system.file("extdata", "rs.data.csv", package="rENA"))

codeNames = c('Data','Technical.Constraints','Performance.Parameters','Client.and.Consultant.Requests','Design.Reasoning','Collaboration');

#DWS code to make combined plot
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

### Subset rotated points and plot Condition 1 Group Mean
first.game = unitNames$Condition == "FirstGame"
first.game.points = set$points.rotated[first.game,]

### Subset rotated points and plot Condition 2 Group Mean
second.game = unitNames$Condition == "SecondGame"
second.game.points = set$points.rotated[second.game,]

#first.game.mean = colMeans( first.game.points )
#second.game.mean = colMeans( second.game.points )

#first.game.ci = t.test(first.game.points, conf.level = 0.95)$conf.int
#second.game.ci = t.test(second.game.points, conf.level = 0.95)$conf.int

### get mean network plots
first.game.lineweights = set$line.weights[first.game,]
first.game.mean = colMeans(first.game.lineweights)

second.game.lineweights = set$line.weights[second.game,]
second.game.mean = colMeans(second.game.lineweights)

subtracted.network = first.game.mean - second.game.mean

#Plot subtracted network only
ena.plot(set) %>% ena.plot.network(network = subtracted.network)

#plot means only
ena.plot(set) %>%
  ena.plot.group(second.game.points, labels = "SecondGame", colors  = "blue", confidence.interval = "box")  %>%
  ena.plot.group(first.game.points, labels = "FirstGame", colors = "red", confidence.interval = "box")

#plot both
ena.plot(set) %>% ena.plot.network(network = subtracted.network) %>%
  ena.plot.group(first.game.points, labels = "FirstGame", colors = "red", confidence.interval = "box") %>%
  ena.plot.group(second.game.points, labels = "SecondGame", colors  = "blue", confidence.interval = "box")
