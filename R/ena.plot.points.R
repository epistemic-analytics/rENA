
ena.plot.points = function(
  enaplot,

  points = NULL,    #vector of unit names or row indices

  labels = unique(enaplot$enaset$enadata$units),
  label.offset = NULL,

  label.font.size = enaplot$get("font.size"),
  label.font.color = enaplot$get("font.color"),
  label.font.family = c("Arial", "Courier New", "Times New Roman"),

  shape = c("circle", "square", "triangle", "diamond"),
  colors = rep(I("black"), nrow(enaplot$enaset$get.data("rotated", with.meta=T))),

  confidence.interval = NULL,
  confidence.interval.shape = c("none", "crosshairs", "box"),

  outlier.interval = NULL,
  outlier.interval.shape = c("none", "crosshairs", "box")

) {

  dfDT = points;

  ### TEST
  if(!is.character(label.font.family)) {
    label.font.size = enaplot$get("font.family");
  }

  confidence.interval.shape = match.arg(confidence.interval.shape);
  outlier.interval.shape = match.arg(outlier.interval.shape);
  shape = match.arg(shape);

  #### ADDRESS THIS
  size = 5;

  ##### WHAT IS THIS?
  evs = enaplot$enaset$data$centered$latent[1:enaplot$enaset$get("dimensions")];
  evs = floor(evs/sum(evs)*100);
  network.graph.axis <- list(title = "", showgrid = T, showticklabels = T, zeroline = T);
  network.graph.axis.x = network.graph.axis.y = network.graph.axis;
  #####

  points.layout = data.frame(dfDT);

  if(length(colors) == 1) {
    colors = rep(colors, nrow(points.layout))
  }

  enaplot$plot %<>% plotly::add_data(points.layout)
  enaplot$plot %<>% plotly::add_trace(x = ~X1, y = ~X2, data = points.layout,
                                      mode = "markers", type = "scatter",
                                      marker = list(
                                        symbol = shape,
                                        color = colors,
                                        size = size
                                      ),
                                      text = ~labels, hoverinfo = "text+x+y");

  ### if number of labels provided is equal to number of points, add labels
  if(length(labels) == nrow(points.layout)) {
    #### label offset weighting
    if(is.null(label.offset)) { label.offset = c(.05,.05) }
    else label.offset = c(label.offset[1] * 0.1, label.offset[2] * 0.1)

    enaplot$plot %<>% plotly::add_annotations( x = points.layout$V1 + label.offset[,1],
                                               y = group.layout$V2 + label.offset[,2],
                                               text = labels,
                                               font = text.info,
                                               xref = "x",
                                               yref = "y",
                                               ax = label.offset[1],
                                               ay = label.offset[2],
                                               showarrow = F);
  }

  #enaplot$plot %<>% plotly::hide_legend();

  enaplot$plot %<>% plotly::layout(
    title = enaplot$plot.title,
    #### do these 2 lines do anything?
    xaxis = network.graph.axis.x,
    yaxis = network.graph.axis.y
  )

  return(enaplot);
}
