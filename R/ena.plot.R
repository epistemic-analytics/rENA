

ena.plot <- function(
  enaset,

  plot.title = "ENA Plot",
  plot.mode = "units+network",
  plot.color = I("black"),

  dimensions = c(1,2),
  dimension.labels = c("x","y"),
  dimension.show.variance = T,

  multiplier = 5,
  ...
) {
  plot = NULL;

  show.modes = unlist(strsplit(plot.mode,split="\\+"))
  show.units = "units" %in% show.modes;
  show.networks = "network" %in% show.modes;

  unit.group_by <- match.arg(unit.group_by);
  estimate.network.over <- match.arg(estimate.network.over);

  return(plot);
}
