
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

  if(grepl("^c", confidence.interval) && grepl("^c", outlier.interval)) {
    print("Confidence Interval and Outlier Interval cannot both be crosshair");
    print("Plotting Outlier Interval as box");
    outlier.interval = "box";
  }

  #### ADDRESS THIS
  size = 5;

  ##### WHAT IS THIS?
  evs = enaplot$enaset$data$centered$latent[1:enaplot$enaset$get("dimensions")];
  evs = floor(evs/sum(evs)*100);
  max.axis = max(abs(points))*1.2;
  network.graph.axis <- list(title = "", showgrid = T, showticklabels = T, zeroline = T, range=c(-max.axis,max.axis));
  network.graph.axis.x = network.graph.axis.y = network.graph.axis;
  #####

  points.layout = data.table::data.table(points);


  if(length(colors) == 1) {
    colors = rep(colors, nrow(points.layout))
  }

  color = colors; #label.font.color
  error = NULL;
  if(grepl("^c", confidence.interval) && !is.null(confidence.interval.values)) {
    ci.x = confidence.interval.values[1];
    ci.y = confidence.interval.values[2];
    error = list(
      x = list(type = "data", array = ci.x),
      y = list(type = "data", array = ci.y)
    )
  } else if(grepl("^c", outlier.interval) && !is.null(outlier.interval.values)) {
    oi.x = outlier.interval.values[1];
    oi.y = outlier.interval.values[2];
    error = list(
      x = list(type = "data", array = oi.x),
      y = list(type = "data", array = oi.y)
    )
  }

  # Control the column names
  colnames(points.layout) = paste0("X", rep(1:ncol(points.layout)));
  if(grepl("^b", confidence.interval) && !is.null(confidence.interval.values)) {
    points.layout[,c("ci.x", "ci.y") := .(confidence.interval.values[1], confidence.interval.values[2])]
    points.layout[, c("ci.x1", "ci.x2", "ci.y1", "ci.y2") := .(X1 - ci.x, X1 + ci.x, X2 - ci.y, X2 + ci.y)]

    lines.CI = apply(points.layout,1,function(x) {
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
  if(grepl("^b", outlier.interval) && !is.null(outlier.interval.values)) {
    oi.x = outlier.interval.values[1];
    oi.y = outlier.interval.values[2];

    points.layout[,c("oi.x", "oi.y") := .(oi.x, oi.y)]
    points.layout[, c("oi.x1", "oi.x2", "oi.y1", "oi.y2") := .(X1 - oi.x, X1 + oi.x, X2 - oi.y, X2 + oi.y)]

    lines.OI = apply(points.layout,1,function(x) {
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
    if(!is.null(error)) {
      #plot group w/ crosshair error bars
      enaplot$plot = plotly::add_trace(
        enaplot$plot,
        data = points.layout,
        # type="scatter",
        x = ~X1, y = ~X2,
        mode="markers+text",
        marker = list(
          symbol =  shape,
          color = color,
          size = size,
          name = "testing"
        ),
        text = labels,
        textposition = "top right",
        error_x = error$x,
        error_y = error$y,
        showlegend = T
        # hoverinfo = "text+x+y"
      )
    } else {
      #plot group w/o crosshair error bars
      enaplot$plot = plotly::add_trace(
        p = enaplot$plot,
        data = points.layout,
        type="scatter",
        x = ~X1, y = ~X2,
        mode="markers",
        marker = list(
          symbol = shape,
          color = color,
          size = size
        ),
        text = labels,
        showlegend = T,
        hoverinfo = "text+x+y"
      )
    }
  }

  ### if number of labels provided is equal to number of points, add labels
  # if(length(labels) == nrow(points.layout)) {
  #   enaplot$plot = plotly::layout(
  #       p = enaplot$plot,
  #       annotations = list(
  #         x = points.layout$X1,
  #         y = points.layout$X2,
  #         text = labels,
  #         xref = "x",
  #         yref = "y",
  #         xanchor = "right",
  #         yanchor = "bottom",
  #         clicktoshow = "onoff",
  #         xshift = label.offset[1],
  #         yshift = label.offset[2],
  #         showarrow = F
  #       )
  #   );
  # }

  enaplot$plot = plotly::layout(
    enaplot$plot,
    title = enaplot$plot.title,
    shapes = lines,
    xaxis = network.graph.axis.x,
    yaxis = network.graph.axis.y
  )

  return(enaplot);
}
