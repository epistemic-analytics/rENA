### ENA Wrapper Function ###

require(rENA)

ena.wrapper = function(data,
                       codes,
                       units,
                       conversations,
                       metadata,
                       windowType,
                       windowSize,
                       groupCol,
                       group1,
                       group2,
                       showPlots){


  accum = ena.accumulate.data(
    units = data[,units],
    conversation = data[,conversations],
    metadata = data[,metadata],
    codes = data[,codes],
    window = windowType,
    window.size.back = windowSize
  );

#Plot mean network of all points if no group column is specified

  if(is.null(groupCol) == TRUE){

    set = ena.make.set(
      enadata = accum
    )

    points = set$points.rotated
    lineweights = set$line.weights
    mean = colMeans(lineweights)

    plot1 = ena.plot(enaset = set, title = "Mean Network -- All Units")
    plot1 = ena.plot.network(plot1, network = mean, colors = "black")
    plot1 = ena.plot.group(plot1, points, colors = "black", labels = "Mean")

    if(showPlots == TRUE){

      print(plot1)
    }

    return(list(set = set, mean.plot = plot1))

  }

  # Plot mean network of one group if user specifies group column and one group

  else if(is.null(group2) == TRUE){

    set = ena.make.set(
      enadata = accum
    )

    metaNames = data.frame(set$enadata$metadata)
    group1.rows = metaNames[,groupCol] == group1
    group1.points = set$points.rotated[group1.rows,]

    group1.lineweights = set$line.weights[group1.rows,]
    group1.mean = colMeans(group1.lineweights)

    plot1 = ena.plot(set, title = paste0("Mean Network -- ",group1))
    plot1 = ena.plot.network(plot1, network = group1.mean)
    plot1 = ena.plot.group(plot1, group1.points, labels = group1, colors = "red", confidence.interval = "box")

    if(showPlots == TRUE){

      print(plot1)
    }

    return(list(set = set, group1.plot = plot1))

  }

  # Plot mean network subtraction if user specifies group column and two groups

  else{

    set = ena.make.set(
      enadata = accum,
      rotation.by = rENA:::ena.rotate.by.mean,
      rotation.params = list(accum$metadata[,..groupCol] == group1, accum$metadata[,..groupCol]== group2)

    )

    metaNames = data.frame(set$enadata$metadata)
    group1.rows = metaNames[,groupCol] == group1
    group1.points = set$points.rotated[group1.rows,]

    group2.rows = metaNames[,groupCol] == group2
    group2.points = set$points.rotated[group2.rows,]

    group1.lineweights = set$line.weights[group1.rows,]
    group1.mean = colMeans(group1.lineweights)

    group2.lineweights = set$line.weights[group2.rows,]
    group2.mean = colMeans(group2.lineweights)

    subtracted.network = group1.mean - group2.mean

    #plot group 1 mean network

    plot1 = ena.plot(set, title = paste0("Mean Network -- ",group1))
    plot1 = ena.plot.network(plot1, network = group1.mean)
    plot1 = ena.plot.group(plot1, group1.points, labels = group1, colors = "red", confidence.interval = "box")


    #plot group 2 mean network

    plot1 = ena.plot(set, title = paste0("Mean Network -- ",group2))
    plot2 = ena.plot.network(plot2, network = group2.mean, colors = "blue")
    plot2 = ena.plot.group(plot2, group2.points, labels = group2, colors  = "blue", confidence.interval = "box")


    #Plot subtracted network and means

    plot3 = ena.plot(set, title = paste0("Network Subtraction -- ",group1," vs ",group2))
    plot3 = ena.plot.network(plot3, network = subtracted.network)
    plot3 = ena.plot.group(plot3, group1.points, labels = group1, colors = "red", confidence.interval = "box")
    plot3 = ena.plot.group(plot3, group2.points, labels = group2, colors  = "blue", confidence.interval = "box")

    if(showPlots == TRUE){

      print(plot1)
      print(plot2)
      print(plot3)
    }

    return(list(set = set, group1.plot = plot1, group2.plot = plot2, network.subtraction = plot3))

  }

}
















