
ena.plot.points = function(
  enaplot,
  data = enaplot$enaset$get.data("rotated", with.meta=T),

  dimension.labels = c("x","y"),
  dimension.show.variance = T,

  units = unique(enaplot$enaset$get("enaData")$get("units")),

  size = 1,
  size.multiplier = 5,
  colors = rep(I("blue"), nrow(data)),

  ##### ena.plot.group now completely separate function
  #group.by = NULL,
  #group.size = NULL,

  trajectory.by = enaplot$trajectory.by,

  font.size = enaplot$font.size,
  font.color = enaplot$font.color,
  font.family = enaplot$font.family

) {

  dfDT = data[ENA_UNIT %in% units];

  df.names = dfDT$ENA_UNIT;
  if(is.null(df.names)) {
    df.names = as.character(1:nrow(data))
    rownames(data) = df.names;
  }
  dfDT[,name:=ENA_UNIT] # Create a name column

  ##### relevant to units - change to plot.vertices ###### NOT USED ANYWHERE?
  # network.vertices.df = dfDT[ENA_UNIT %in% units,c(ncol(dfDT),1:ncol(dfDT)-1),with=F];
  # network.font.text = list(
  #   family = font.family,
  #   size = font.size,
  #   color = font.color
  # );
  #####

  evs = enaplot$enaset$data$centered$latent[1:enaplot$enaset$get("dimensions")];
  evs = floor(evs/sum(evs)*100);

  network.graph.axis <- list(title = "", showgrid = T, showticklabels = T, zeroline = T);
  network.graph.axis.x = network.graph.axis.y = network.graph.axis;

  if(dimension.show.variance == T) {
    network.graph.axis.x$title = paste(dimension.labels[1], " (", evs[1], "%)", sep = "");
    network.graph.axis.y$title = paste(dimension.labels[2], " (", evs[2], "%)", sep = "");
  } else {
    network.graph.axis.x$title = dimension.labels[1];
    network.graph.axis.y$title = dimension.labels[2];
  }

  ## Trajectory model
  if(!is.null(trajectory.by)) {

    #### PLOT GROUP BACK TO ITS OWN FUNCTION
    # if(!is.null(group.by)) {
    #   return(enaplot %<>% ena.plot.groups(trajectory.by = trajectory.by, unit.group = group.by, unit.group.size = group.size));
    # }

    #####WORK MOVED INTO PLOTGROUPS - BACK TO HERE
    dfDT.trajs = dfDT[,{ data.table::data.table(lines = list(.SD))  } ,by=ENA_UNIT]

    for(x in 1:nrow(dfDT.trajs)) {
      toPlot = unique(colnames(dfDT.trajs[x][[2]][[1]]))
      enaplot$plot %<>% plotly::add_trace(
        data = dfDT.trajs[x][[2]][[1]][,toPlot,with=FALSE],
        x = ~V1, y = ~V2,
        name = dfDT.trajs[x][[1]],
        mode = "lines+markers",
        text = dfDT.trajs[x][[2]][[1]]$TRAJ_UNIT,
        hoverinfo = "text+x+y"
      )
    }

    enaplot$plot %<>% plotly::hide_legend();

    return(enaplot);
  }

  ## Non-trajectory model
 else {

    ###### PLOT GROUP BACK TO ITS OWN FUNCTION
    # if(!is.null(group.by)) {
    #   return(enaplot %<>% ena.plot.groups(unit.group = group.by, unit.group.size = group.size))
    # }

    points.layout = data.frame(dfDT);

    if(length(colors) == 1) {
      colors = rep(colors, nrow(data))
    }

    enaplot$plot %<>% plotly::add_data(points.layout) %>% plotly::add_trace(enaplot$plot, x = ~V1, y = ~V2, data = points.layout, mode = "markers", type = "scatter",
      marker = list(
        symbol = c(rep("circle",nrow(data))),
        color = colors,
        size = c(rep(size * size.multiplier, nrow(data)))
      ),
    text = ~name, hoverinfo = "text+x+y");

    enaplot$plot %<>% plotly::hide_legend();

    enaplot$plot %<>% plotly::layout(
      title = enaplot$plot.title,
      xaxis = network.graph.axis.x,
      yaxis = network.graph.axis.y
      #shapes = lines
    )

    return(enaplot);

  }

  return(enaplot);
}
