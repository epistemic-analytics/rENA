##
#' @title Plots points using an ENA Plot
#'
#' @description Plot all or a subset of the points of an ENAplot using the plotly plotting library
#'
#' @details [TBD]
#'
#' @export
#'
#' @param enaplot \code{\link{ENAplot}} object to use for plotting
#' @param points A dataframe of matrix where the first two column are X and Y coordinates
#' @param point.size Size of the point nodes
#' @param labels A character vector of point labels, same length as points or number of total points
#' @param confidence.interval A character determining markings to use, choices: none, box, crosshair, default: none
#' @param outlier.interval A character determining markings to use, choices: none, box, crosshair, default: none
#' @param confidence.interval.values A matrix/dataframe where columns are CI x and y values for each point
#' @param outlier.interval.values A matrix/dataframe where columns are OI x and y values for each point
#' @param shape A character which determines the shape of markers, choices: square, triangle, diamond, circle, default: circle
#' @param colors A character vector of the marker colors, if one given it is used for all, otherwise must be same length as points
#' @param label.offset numeric vector - x and y value to offset labels from the coordinates of the points
#' @param label.group A character vector used to group the labels in the legend
#' @param label.font.size An integer which determines the font size for graph labels, default: enaplot$font.size
#' @param label.font.color A character which determines the color of label font, default: enaplot$font.color
#' @param label.font.family	A character which determines font type, choices: Arial, Courier New, Times New Roman, default: enaplot$font.family
#' @param show.legend Logical indicating whether to show the point labels in the in legend
#' @param ... additional parameters addressed in inner function
#'
#' @keywords ENA, plot, points
#'
#' @seealso \code{\link{ena.plot}}, \code{\link{ENAplot}}, \code{\link{ena.plot.group}}
#'
#' @examples
#' \dontrun{
#' #Given an \code{\link{ENAplot}}
#' ena.plot.points(\code{\link{ENAplot}})
#' }
#'
#' @return \code{\link{ENAplot}} The ENAplot provided to the function, with its plot updated to include the new points.
##
ena.plot.points = function(
  enaplot,

  points = NULL,    #vector of unit names or row indices
  point.size = 5,
  labels = rownames(points), #unique(enaplot$enaset$enadata$unit.names),
  label.offset = NULL,
  label.group = "Points",
  label.font.size = enaplot$get("font.size"),
  label.font.color = enaplot$get("font.color"),
  label.font.family = c("Arial", "Courier New", "Times New Roman"),

  shape = c("circle", "square", "triangle-up", "diamond"),
  colors = default.colors[1], # c("blue"), #rep(I("black"), nrow(points)),

  confidence.interval.values = NULL,
  confidence.interval = c("none", "crosshairs", "box"),

  outlier.interval.values = NULL,
  outlier.interval = c("none", "crosshairs", "box"),
  show.legend = T,
  ...
) {
  ###
  # Parameter Checking and Cleaning
  ###
    if(is.null(points)) {
      stop("Must provide points to plot.")
    }
    if(is(points, "numeric")){
      points = matrix(points);
      dim(points) = c(1,nrow(points))
    }
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

    points.layout = data.table::data.table(points);
    colnames(points.layout) = paste0("X", rep(1:ncol(points.layout)));

    if(length(colors) == 1) {
      colors = rep(colors, nrow(points.layout))
    }
  ###
  # END: Parameter Checking and Cleaning
  ###

  ###
  # Set error value for CI|OI crosshair on plot
  ###
    error = list(x = list(visible=F, type="data"), y = list(visible=F, type="data"));
    int.values = NULL;
    if(grepl("^c", confidence.interval) && !is.null(confidence.interval.values)) {
      int.values = confidence.interval.values;
    } else if(grepl("^c", outlier.interval) && !is.null(outlier.interval.values)) {
      int.values = outlier.interval.values;
    }
    error$x$array = int.values[1];
    error$y$array = int.values[2];
  ###
  # END: Set error value for crosshair on plot
  ###

  ###
  # Set box value for CI|OI box on plot
  ###
    box.values = NULL;
    if(grepl("^b", confidence.interval) && !is.null(confidence.interval.values)) {
      box.values = confidence.interval.values;
      box.label = "Conf. Int.";
    }
    if(grepl("^b", outlier.interval) && !is.null(outlier.interval.values)) {
      box.values = outlier.interval.values;
      box.label = "Outlier Int.";
    }
  ###
  # END: Set box value for CI|OI box on plot
  ###

  ###
  # Plot
  ###
    for(m in 1:nrow(points.layout)) {
      enaplot$plot = plotly::add_trace(
        p = enaplot$plot,
        data = points.layout[m,],
        type ="scatter",
        x = ~X1, y = ~X2,
        mode = "markers+text",
        marker = list(
          symbol = shape,
          color = colors[m],
          size = point.size
        ),
        error_x = error$x, error_y = error$y,
        showlegend = show.legend,
        # legendgroup = ifelse(!is.null(box.label), labels[1], NULL),
        name = labels[m],
        text = labels[m],
        textposition = "top right",
        hoverinfo = "text+x+y"
      )
    }

    if(!is.null(box.values)) {
      box.values = data.frame(
        X1 = c(points[1]-box.values[1],points[1]+box.values[1],points[1]+box.values[1],points[1]-box.values[1],points[1]-box.values[1]),
        X2 = c(points[2]-box.values[2],points[2]-box.values[2],points[2]+box.values[2],points[2]+box.values[2],points[2]-box.values[2])
      )
      enaplot$plot = plotly::add_trace(
        p = enaplot$plot,
        data = box.values,
        type = "scatter",
        x = ~X1, y = ~X2,
        mode = "lines",
        line = list(
          width = 1,
          color = colors[1],
          dash = "dash"
        ),
        # "legendgroup" = labels[1],
        name = box.label
      )
    }
  ###
  # END: Plot
  ###

  return(enaplot);
}
