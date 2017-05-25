##
#' @title Generate Plot of ENA set
#'
#' @description Generate a plot of a given ENA set.
#'
#' @details [TBD]
#'
#' @export
#'
#' @param enaset \code{\link{ENAset}} used to generate the plot
#' @param plot.title Title of the plot
#' @param plot.mode
#' @param plot.color Color of the plot
#' @param dimensions Number of dimensions in the plot
#' @param dimension.labels Labels for the dimensions of the plot
#' @param dimension.show.variance
#' @param multiplier Size multiplier for the plot
#' @param units Vector of units to plot
#' @param unit.colors Color of units
#' @param unit.labels Names of units
#' @param unit.labels.positions Location of names of units
#' @param unit.size change size of unit label
#' @param unit.size.multiplier Change size multiplier of unit labels
#' @param unit.show.confidence.intervals Show confidence intervals of a unit
#' @param unit.group
#' @param unit.group_by
#' @param unit.group.labels
#' @param unit.group.labels.positions
#' @param unit.group.labels.colors
#' @param unit.group.size
#' @param unit.group.size.multiplier
#' @param network.one
#' @param network.two
#' @param network.colors
#' @param network.show.all.codes
#' @param network.code.labels
#' @param network.code.labels.positions
#' @param network.edge.threshold
#' @param axis.flip.x Flip plot on x-axis
#' @param axis.flip.y Flip plot on y-axis
#' @param estimate.network.over Adjusts weights using what is being plotted or what is in the entire set
#' @param ... Additional parameters addressed in inner function
#'
#' @keywords ENA, plot, set
#'
#' @seealso \code{\link{ena.make.data}}, \code{\link{ena.update.data}}
#'
#' @examples
#' # Given an ENA set
#' ena.plot.set(\code{\link{ENAset}})
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
  return(plot);
}
