
ena.plot.points = function(
  enaplot,

  points = NULL,    #vector of unit names or row indices

  #dimension.labels = c("x","y"),
  #dimension.show.variance = T,

  labels = unique(enaplot$enaset$enadata$units),

  label.offset = NULL,

  label.font.size = enaplot$get("font.size"),
  label.font.color = enaplot$get("font.color"),
  label.font.family = enaplot$get("font.family"),

  colors = rep(I("black"), nrow(enaplot$enaset$get.data("rotated", with.meta=T)))

) {

  data = enaplot$enaset$get.data("rotated", with.meta=T);

  ### probably doesnt work for subsetting - TEST IT
  if(!is.null(points)){
    if(is.numeric(points[1])) {
      data = data[points,];
    } else {
      data = data[ENA_UNIT %in% points];
    }
  }

  size = 5;

  #### used to determine trajectory or not, make sure it is null if not doing traject
  trajectory.by = enaplot$enaset$enadata$get("trajectory.by");

  #### MAY NOT BE HOW WE WANT TO USE LABELS
  # if(!is.null(labels)) {
  #   dfDT = data[ENA_UNIT %in% labels];
  # } else dfDT = data;
  dfDT = data;

  ### THIS CHUNK SHOULDNT BE NEEDED, ENA_UNIT should always be a column
  df.names = dfDT$ENA_UNIT;
  if(is.null(df.names)) {
    df.names = as.character(1:nrow(data))
    rownames(data) = df.names;
  }

  dfDT[,name:=ENA_UNIT] # Create a name column



  evs = enaplot$enaset$data$centered$latent[1:enaplot$enaset$get("dimensions")];
  evs = floor(evs/sum(evs)*100);

  network.graph.axis <- list(title = "", showgrid = T, showticklabels = T, zeroline = T);
  network.graph.axis.x = network.graph.axis.y = network.graph.axis;

  # if(dimension.show.variance == T) {
  #   network.graph.axis.x$title = paste(dimension.labels[1], " (", evs[1], "%)", sep = "");
  #   network.graph.axis.y$title = paste(dimension.labels[2], " (", evs[2], "%)", sep = "");
  # } else {
  #   network.graph.axis.x$title = dimension.labels[1];
  #   network.graph.axis.y$title = dimension.labels[2];
  # }

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
      colors = rep(colors, nrow(points.layout))
    }

    enaplot$plot %<>% plotly::add_data(points.layout) %>% plotly::add_trace(x = ~V1, y = ~V2, data = points.layout,
      mode = "markers", type = "scatter",
        marker = list(
          symbol = c(rep("circle",nrow(points.layout))),
          color = colors,
          size = c(rep(size, nrow(points.layout)))
        ),
      text = ~name, hoverinfo = "text+x+y");

    #enaplot$plot %<>% plotly::hide_legend();

    enaplot$plot %<>% plotly::layout(
      title = enaplot$plot.title,
      xaxis = network.graph.axis.x,
      yaxis = network.graph.axis.y
    )

    return(enaplot);

  }

  return(enaplot);
}
