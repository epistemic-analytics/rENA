##
#' @title Generate ENA Set
#'
#' @description Generate an ENA set from a given ENA data object
#'
#' @details NEED TO ADD
#'
#' @export
#'
#' @param ena.set \code{\link{ENASet}} from ena.generate.set()
#' @param plot.title Title of plot
#' @param plot.mode
#' @param dimensions Number of dimensions in plot
#' @param dimension.labels Labels of axes
#' @param dimension.show.variance
#'
#' @param units Units of plot
#' @param unit.labels Units of labels
#' @param unit.label.positions
#' @param unit.colors Color of units
#' @param units.groups.by
#'
#' @param plot.group.points
#' @param plot.group.points.by
#' @param plot.group.point.labels
#' @param plot.group.point.label.positions
#' @param plot.group.point.colors
#'
#' @param network.one Name of unit/mean
#' @param network.two Name of unit/mean
#' @param network.colors
#' @param network.show.all.codes
#' @param network.code.labels
#' @param network.code.label.positions
#' @param network.edge.threshold
#'
#' @keywords ENA, plot, set
#'
#' @seealso \code{\link{ena.make.data()}}, \code{\link{ena.update.data()}}
#'
#' @examples
#' #ADD EXAMPLES
#'
#' @return Plot of \code{\link{ENAset}}
##
ena.plot.set <- function(
  enaset,
  plot.title = "ENA Plot",
  plot.mode = "units+network",
  plot.color = I("black"),

  dimensions = c(1,2),
  dimension.labels = c("x","y"),
  dimension.show.variance = T,

  multiplier = 5,



  units = unique(enaset$get("enaData")$get("units")),
  unit.colors = rep(plot.color, nrow(enaset$data$centered$rotated)),
  unit.labels = units,
  unit.labels.positions = NULL,
  unit.size = 1,
  unit.size.multiplier = multiplier,
  unit.show.confidence.intervals = T,

  unit.group = NULL,
  unit.group_by = c("mean","sum"),
  unit.group.labels = names(unit.groups),
  unit.group.labels.positions = "top right",
  unit.group.labels.colors = rep(plot.color, length(unit.group)),
  unit.group.size = unit.size,
  unit.group.size.multiplier = unit.size.multiplier,

  network.one = NULL,
  network.two = NULL,
  network.colors = NULL,
  network.show.all.codes = F,
  network.code.labels = rownames(enaset$nodes$positions$scaled),
  network.code.labels.positions = NULL,
  network.edge.threshold = 0,

  axis.flip.x = F,
  axis.flip.y = F,

  estimate.network.over = c("plot","set"),

  ...
) {
  plot = NULL

  show.modes = unlist(strsplit("units+network",split="\\+"))
  show.units = "units" %in% show.modes;
  show.networks = "network" %in% show.modes;

  unit.group_by <- match.arg(unit.group_by);
  estimate.network.over <- match.arg(estimate.network.over);

  if(show.units && !is.null(units)){
    plot = ena.plot.units(
      enaset = enaset, plot.title = plot.title,
      unit.size = unit.size,
      unit.colors = unit.colors,
      unit.group = unit.group,
      unit.show.confidence.intervals = unit.show.confidence.intervals,
      unit.group.size = unit.group.size,
      unit.group.size.multiplier = unit.group.size.multiplier
    );
  }
  if(show.networks && !is.null(network.one)) {
    plot = ena.plot.network(
      enaset = enaset,
      plot = plot,
      selection.one.name = network.one
    )
  }
browser();
  return(plot);
}
