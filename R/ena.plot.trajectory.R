##
#' @title Plot of ENA trajectories
#'
#' @description Function used to plot trajectories
#'
#' @details
#'
#' @export
#'
#' @param enaplot \code{\link{ENAplot}} object to use for plotting
#' @param points dataframe of matrix - first two column are X and Y coordinates, each row is a step in some trajectory
#' @param by vector used to subset points into individual trajectories (subset of trajectories$units)
#' @param labels character vector - point labels, same length as points or number of total points
#' @param confidence.interval A character that determines which confidence interval type to use, choices: none, box, crosshair, default: none
#' @param outlier.interval A character that determines which outlier interval type to use, choices: none, box, crosshair, default: none
#' @param confidence.interval.values A matrix/dataframe where columns are CI x and y values for each point
#' @param outlier.interval.values A matrix/dataframe where columns are OI x and y values for each point
#' @param color A character, determines marker color, default: enaplot$color
#' @param shape A character which determines the shape of markers, choices: square, triangle, diamond, circle, default: circle
#' @param label.offset A numeric vector of an x and y value to offset labels from the coordinates of the points
#' @param label.font.size An integer which determines the font size for graph labels, default: enaplot$font.size
#' @param label.font.color A character which determines the color of label font, default: enaplot$font.color
#' @param label.font.family A character which determines font type, choices: Arial, Courier New, Times New Roman, default: enaplot$font.family
#' @param ... Additional parameters
#'
#' @keywords ENA, plot, trajectory
#'
#' @seealso \code{\link{ena.plot}}
#'
#' @examples
#' \dontrun{
#' # Given an ENA plot
#' ena.plot.trajectory(\code{\link{ENAplot}})
#'
#' }
#' @return The  \code{\link{ENAplot}} provided to the function, with its plot updated to include the trajectories subsetted using the by parameter
##

ena.plot.trajectory = function(
  enaplot,
  points,
  by = NULL,
  labels = NULL, #unique(enaplot$enaset$enadata$units),
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
    by = list(all = rep(T, nrow(points)));
  }
  if(!is(points, "data.table")) {
    points = data.table::as.data.table(points);
  }
  if(is.null(labels)) {
    labels = rownames(points);
  }

  tbl = data.table::data.table(points, labels = labels);
  dfDT.trajs = tbl[,{ data.table::data.table(lines = list(.SD))  }, by=by]

  for(x in 1:nrow(dfDT.trajs)) {
    enaplot$plot = plotly::add_trace(
      enaplot$plot,
      data = dfDT.trajs[x,]$lines[[1]],
      x = ~V1, y = ~V2,
      name = as.character(names[x]), #dfDT.trajs[x]$lines[[1]]$labels,
      mode = "lines+markers+text",
      text = dfDT.trajs[x,]$lines[[1]]$labels,
      textposition = 'middle right',
      hoverinfo = "x+y"
      #,visible = "legendonly"
    );
  }

  max.axis = max(abs(points))*1.2;
  network.graph.axis <- list(title = "", showgrid = T, showticklabels = T, zeroline = T, range=c(-max.axis,max.axis));
  network.graph.axis.x = network.graph.axis.y = network.graph.axis;

  enaplot$plot = plotly::layout(
    enaplot$plot,
    title = enaplot$plot.title,
    shapes = lines,
    xaxis = network.graph.axis.x,
    yaxis = network.graph.axis.y
  )
  return(enaplot);
}
