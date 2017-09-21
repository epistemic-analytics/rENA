
ena.plot.points = function(
  enaplot,

  points = NULL,    #vector of unit names or row indices

  labels = rownames(points), #unique(enaplot$enaset$enadata$unit.names),
  label.offset = NULL,

  label.font.size = enaplot$get("font.size"),
  label.font.color = enaplot$get("font.color"),
  label.font.family = c("Arial", "Courier New", "Times New Roman"),

  shape = c("circle", "square", "triangle", "diamond"),
  colors = c("black"), #rep(I("black"), nrow(points)),

  confidence.interval.values = NULL,
  confidence.interval = c("none", "crosshairs", "box"),

  outlier.interval.values = NULL,
  outlier.interval = c("none", "crosshairs", "box")

) {
  if(is(points, "numeric")){
    points = matrix(points);
    dim(points) = c(1,nrow(points))
  }
  group.layout = NULL;
  if(!is.character(label.font.family)) {
    label.font.size = enaplot$get("font.family");
  }

  confidence.interval = match.arg(confidence.interval);
  outlier.interval = match.arg(outlier.interval);
  shape = match.arg(shape);

  if(confidence.interval == "crosshair" && outlier.interval == "crosshair") {
    print("Confidence Interval and Outlier Interval cannot both be crosshair");
    print("Plotting Outlier Interval as box");
    outlier.interval = "box";
  }

  #### ADDRESS THIS
  size = 5;

  ##### WHAT IS THIS?
  evs = enaplot$enaset$data$centered$latent[1:enaplot$enaset$get("dimensions")];
  evs = floor(evs/sum(evs)*100);
  network.graph.axis <- list(title = "", showgrid = T, showticklabels = T, zeroline = T);
  network.graph.axis.x = network.graph.axis.y = network.graph.axis;
  #####

  points.layout = data.frame(points);

  ### Check number of labels equal to number of points given or number of total points if none given
  #if(length(labels) != )

  if(length(colors) == 1) {
    colors = rep(colors, nrow(points.layout))
  }

  color = colors; #label.font.color
  error = NULL;
  if(confidence.interval == "crosshair" && !is.null(confidence.interval.values)) {
    ci.x = confidence.interval.values[1];
    ci.y = confidence.interval.values[2];
    error = list(
      x = list(type = "data", array = ci.x),
      y = list(type = "data", array = ci.y)
    )
  } else if(outlier.interval == "crosshair" && !is.null(outlier.interval.values)) {
    oi.x = outlier.interval.values[1];
    oi.y = outlier.interval.values[2];
    error = list(
      x = list(type = "data", array = oi.x),
      y = list(type = "data", array = oi.y)
    )
  }

  colnames(points.layout) = paste0("X", rep(1:ncol(points.layout)));
  if(confidence.interval == "box" && !is.null(confidence.interval.values)) {

    conf.ints = t.test(points.raw, conf.level = .95)$conf.int;
    dfDT.points[,c("ci.x", "ci.y") := .(conf.ints[1], conf.ints[2])]

    #add cols for coordinates of CI lines
    dfDT.points[, c("ci.x1", "ci.x2", "ci.y1", "ci.y2") := .(X1 - ci.x, X1 + ci.x, X2 - ci.y, X2 + ci.y)]

    lines.CI = apply(dfDT.points,1,function(x) {
      list(
        "type" = "square",
        "line" = list(
          width = 1,
          color = color,
          dash="dash"
        ),
        "xref" = "x",
        "yref" = "y",
        "x0" = x[['ci.x1']],
        "x1" = x[['ci.x2']],
        "y0" = x[['ci.y1']],
        "y1" = x[['ci.y2']]
      );
    });
    lines = lines.CI;
  }
  if(outlier.interval == "box" && !is.null(outlier.interval.values)) {

    oi.x = outlier.interval.values[1];
    oi.y = outlier.interval.values[2];

    dfDT.points[,c("oi.x", "oi.y") := .(oi.x, oi.y)]

    #add cols for coordinates of CI lines
    dfDT.points[, c("oi.x1", "oi.x2", "oi.y1", "oi.y2") := .(V1 - oi.x, V1 + oi.x, V2 - oi.y, V2 + oi.y)]

    lines.OI = apply(dfDT.points,1,function(x) {
      list(
        "type" = "square",
        "line" = list(
          width = 1,
          color = color,
          dash="dash"
        ),
        "xref" = "x",
        "yref" = "y",
        "x0" = x[['oi.x1']],
        "x1" = x[['oi.x2']],
        "y0" = x[['oi.y1']],
        "y1" = x[['oi.y2']]
      );
    });

    lines = c(lines, lines.OI);
  }

  if(!is.null(points.layout)) {
    #### NEW
    if(!is.null(error)) {
      #plot group w/ crosshair error bars
      enaplot$plot = plotly::add_trace(
        enaplot$plot,
        data = points.layout,
        type="scatter",
        x = ~X1, y = ~X2,
        mode="markers",
        marker = list(
          symbol =  shape,
          color = color,
          size = size
        ),
        error_x = error$x,
        error_y = error$y,
        showlegend = F,
        hoverinfo = "text+x+y"
      )
    } else {
      #plot group w/o crosshair error bars
      enaplot$plot = plotly::add_trace(
        enaplot$plot,
        data = points.layout,
        type="scatter",
        x = ~X1, y = ~X2,
        mode="markers",
        marker = list(
          symbol =  shape,  #c(rep("circle",nrow(data)),rep("square", ifelse(!is.null(dfDT.groups), nrow(dfDT.groups), 0))),
          color = color,
          #size = c(rep(unit.size * unit.size.multiplier, nrow(data)), rep(group.size, ifelse(!is.null(dfDT.groups),nrow(dfDT.groups), 0)))
          size = size
        ),
        showlegend = F,
        hoverinfo = "text+x+y"
      )
    }
  }

  #### OLD
  # enaplot$plot %<>% plotly::add_data(points.layout)
  # enaplot$plot %<>% plotly::add_trace(x = ~X1, y = ~X2, data = points.layout,
  #                                     mode = "markers", type = "scatter",
  #                                     marker = list(
  #                                       symbol = shape,
  #                                       color = colors,
  #                                       size = size
  #                                     ),
  #                                     text = ~labels, hoverinfo = "text+x+y");
  ####

  # browser()
  ### if number of labels provided is equal to number of points, add labels
  if(length(labels) == nrow(points.layout)) {
    #### label offset weighting
    if(is.null(label.offset)) { label.offset = c(0.05,0.02) }
    else label.offset = c(label.offset[1] * 0.1, label.offset[2] * 0.1)
    enaplot$plot = plotly::add_annotations( enaplot$plot, x = points.layout$X1 + label.offset[1],
                                               y = points.layout$X2 + label.offset[2],
                                               text = labels,
                                               # font = text.info,
                                               xref = "x",
                                               yref = "y",
                                               ax = label.offset[1],
                                               ay = label.offset[2],
                                               showarrow = F);
  }

  #enaplot$plot %<>% plotly::hide_legend();

  enaplot$plot = plotly::layout(
    enaplot$plot,
    title = enaplot$plot.title,
    shapes = lines,
    #### do these 2 lines do anything?
    xaxis = network.graph.axis.x,
    yaxis = network.graph.axis.y
  )

  return(enaplot);
}
