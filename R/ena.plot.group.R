##
#' @title Plot of ENA set groups
#'
#' @description Generate a plot of a given groups for an ENA plot.
#'
#' @details [TBD]
#'
#' @export
#'
#' @param enaplot \code{\link{ENAplot}} used to generate the plot
#' @param confidence.interval Show confidence intervals of a unit
#' @param points [TBD]
#' @param color [TBD]
#' @param shape [TBD]
#' @param outlier.interval [TBD]
#' @param label [TBD]
#' @param label.offset [TBD]
#' @param label.font.size [TBD]
#' @param label.font.color [TBD]
#' @param label.font.family [TBD]
#' @param ... Additional parameters addressed in inner function
#'
#' @keywords ENA, plot, set
#'
#' @seealso \code{\link{ena.make.set}}, \code{ena.update.set}
#'
#' @examples
#' \dontrun{
#' # Given an ENA plot
#' ena.plot.set(\code{\link{ENAplot}})
#'
#' }
#' @return Plot of groups of \code{\link{ENAplot}}
##
ena.plot.group <- function(
  enaplot,

  points = NULL,

  label = NULL,

  color = "black",
  shape = c("square", "triangle", "diamond", "circle"),

  confidence.interval = c("none", "crosshairs", "box"),
  outlier.interval = c("none", "crosshairs", "box"),

  label.offset = NULL,

  label.font.size = enaplot$font.size,
  label.font.color = enaplot$font.color,
  label.font.family = enaplot$font.family,
  ...
) {

  confidence.interval = match.arg(confidence.interval);
  outlier.interval = match.arg(outlier.interval);
  ### problem if outlier and confidence intervals selected for crosshair
  if(confidence.interval == "crosshair" && outlier.interval == "crosshair") {
    print("Confidence Interval and Outlier Interval cannot both be crosshair");
    print("Plotting Outlier Interval as box");
    outlier.interval = "box";
  }

  shape = match.arg(shape);

  size = 5;

  text.info = list(
    family = label.font.family,
    size = label.font.size,
    color = label.font.color
  )

  #### should we plot mean for all points if points not provided?
  if(is.null(points)) points = enaplot$enaset$points.rotated;
  colnames(points) = c("V1", "V2");

  ### save raw points for later calculations of confidence/outlier intervals
  points.raw = points;

  ### if group more than one row, combine to mean
  if(nrow(points) > 1) {
    points = colMeans(points);
    dfDT.points = data.table("V1" = points[1], "V2" = points[2]);
  } else {
    dfDT.points = data.table("V1" = points[,1], "V2" = points[,2]);
  }
  group.layout = data.frame(dfDT.points);

  ### INTERVAL CALCULATIONS
  error = NULL;
  lines = list();

  if(confidence.interval == "crosshair") {
    ci.x = t.test(points.raw, conf.level = .95)$conf.int[1];
    ci.y = t.test(points.raw, conf.level = .95)$conf.int[2];
    error = list(
      x = list(type = "data", array = ci.x),
      y = list(type = "data", array = ci.y)
    )
  } else if(outlier.interval == "crosshair") {
    oi.x = IQR(points.raw$V1) * 1.5;
    oi.y = IQR(points.raw$V2) * 1.5;
    error = list(
      x = list(type = "data", array = oi.x),
      y = list(type = "data", array = oi.y)
    )
  }

  if(confidence.interval == "box") {

    conf.ints = t.test(points.raw, conf.level = .95)$conf.int;
    dfDT.points[,c("ci.x", "ci.y") := .(conf.ints[1], conf.ints[2])]

    #add cols for coordinates of CI lines
    dfDT.points[, c("ci.x1", "ci.x2", "ci.y1", "ci.y2") := .(V1 - ci.x, V1 + ci.x, V2 - ci.y, V2 + ci.y)]

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
  if(outlier.interval == "box") {

    oi.x = IQR(points.raw$V1) * 1.5;
    oi.y = IQR(points.raw$V2) * 1.5;

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


  if(!is.null(error)) {
    #plot group w/ crosshair error bars
    enaplot$plot = plotly::add_trace(
      enaplot$plot,
      data = group.layout,
      type="scatter",
      x = ~V1, y = ~V2,
      mode="markers",
      marker = list(
        symbol =  shape,
        color = color,
        size = size
      ),
      error_x = error$x,
      error_y = error$y,
      showlegend = F,
      text = label,
      hoverinfo = "text+x+y"
    )
  } else {
    #plot group w/o crosshair error bars
    enaplot$plot = plotly::add_trace(
      enaplot$plot,
      data = group.layout,
      type="scatter",
      x = ~V1, y = ~V2,
      mode="markers",
      marker = list(
        symbol =  shape,  #c(rep("circle",nrow(data)),rep("square", ifelse(!is.null(dfDT.groups), nrow(dfDT.groups), 0))),
        color = color,
        #size = c(rep(unit.size * unit.size.multiplier, nrow(data)), rep(group.size, ifelse(!is.null(dfDT.groups),nrow(dfDT.groups), 0)))
        size = size
      ),
      showlegend = F,
      text = label,
      hoverinfo = "text+x+y"
    )
  }

  ##### WEIGHTING OFFSET
  if(is.null(label.offset)) { label.offset = c(.05,.05) }
  else label.offset = c(label.offset[1] * 0.1, label.offset[2] * 0.1)

  enaplot$plot = plotly::add_annotations(
    enaplot$plot,
    x = group.layout$V1[1] + label.offset[1],
    y = group.layout$V2[1] + label.offset[2],
    text = label,
    font = text.info,
    xref = "x",
    yref = "y",
    ax = label.offset[1],
    ay = label.offset[2],
    #xanchor = "left",
    showarrow = F
  );

  enaplot$plot = plotly::layout(
    enaplot$plot,
    shapes = lines
    #annotations = label.info
  )

  return(enaplot);
}
