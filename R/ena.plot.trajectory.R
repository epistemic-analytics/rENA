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
#' @param confidence.interval character - markings to use, choices: “none”, “box”, “crosshair”, default: none
#' @param outlier.interval character - markings to use, choices: “none”, “box”, “crosshair”, default: none
#' @param confidence.interval.values matrix/dataframe - x and y CI values for each point
#' @param outlier.interval.values matrix/dataframe - x and y OI values for each point
#' @param color character - marker color, default: enaplot$color
#' @param shape character - shape of marker, choices: square, triangle, diamond, circle, default: circle
#' @param label.offset numeric vector - x and y value to offset labels from the coordinates of the points
#' @param label.font.size integer - font size, default: size given in plot initialization
#' @param label.font.color character - font color, default: color given in plot initialization
#' @param label.font.family character - font style, default: font given in plot initialization
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
    enaplot$plot = plotly::add_trace(
      enaplot$plot,
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
