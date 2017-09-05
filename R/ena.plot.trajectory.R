ena.plot.trajectory = function(
  enaplot,
  points,    #dataframe of points
  by = NULL,
  labels = unique(enaplot$enaset$enadata$units),
  names = NULL,
  label.offset = NULL,
  label.font.size = enaplot$get("font.size"),
  label.font.color = enaplot$get("font.color"),
  label.font.family = c("Arial", "Courier New", "Times New Roman"),
  shape = c("circle", "square", "triangle", "diamond"),
  colors = rep(I("black"), length(unique(by)))
) {

  if(!is.character(label.font.family)) {
    label.font.size = enaplot$get("font.family");
  }

  shape = match.arg(shape);

  size = 5;

  ### probably doesnt work for subsetting - TEST IT
  # if(!is.null(points)){
  #   if(is.numeric(points[1])) {
  #     dfDT = dfDT[points,];
  #   } else {
  #     dfDT = dfDT[ENA_UNIT %in% points];
  #   }
  # }

  ### THIS CHUNK SHOULDNT BE NEEDED, ENA_UNIT should always be a column
  # df.names = dfDT$ENA_UNIT;
  # if(is.null(df.names)) {
  #   df.names = as.character(1:nrow(data))
  #   rownames(data) = df.names;
  # }
  #dfDT[,name:=ENA_UNIT] # Create a name column


  network.graph.axis <- list(title = "", showgrid = T, showticklabels = T, zeroline = T);
  network.graph.axis.x = network.graph.axis.y = network.graph.axis;

  if(is.null(by)) {
    by = rep(T, nrow(points));
  }
  if(!is(points, "data.table")) {
    points = data.table::as.data.table(points);
  }
  tbl = cbind(points, labels)
  dfDT.trajs = tbl[,{ data.table::data.table(lines = list(.SD))  } ,by=by]

  for(x in 1:nrow(dfDT.trajs)) {
    #toPlot = unique(colnames(dfDT.trajs[x]$lines[[1]]))
    enaplot$plot %<>% plotly::add_trace(
      data = dfDT.trajs[x]$lines[[1]],
      x = ~V1, y = ~V2,
      name = as.character(names[x]), #dfDT.trajs[x]$lines[[1]]$labels,
      mode = "lines+markers+text",
      text = dfDT.trajs[x]$lines[[1]]$labels,
      textposition = 'middle right',
      hoverinfo = "x+y",
      visible = "legendonly"
    )
  }

  # enaplot$plot %<>% plotly::hide_legend();


  return(enaplot);
}
