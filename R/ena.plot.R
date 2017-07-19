

ena.plot <- function(
  enaset,

  plot.mode = "units+network",
  plot.title = "ENA Plot",
  plot.color = I("black"),

  dimensions = c(1,2),
  dimension.labels = c("x","y"),
  dimension.show.variance = T,

  multiplier = 5,

  ###NEW - may not need
  units = unique(enaset$get("enaData")$get("units")),
  unit.colors = rep(plot.color, nrow(enaset$points.rotated)),
  unit.labels = units,
  unit.labels.positions = NULL,
  unit.size = 1,
  unit.size.multiplier = multiplier,
  unit.show.confidence.intervals = T,
  ####END NEW

  trajectory.by = enaset$get("enadata")$get("trajectory.by"),


  ...
) {

  plot = ENAplot$new(enaset, plot.mode);

  #show.modes = unlist(strsplit(plot.mode,split="\\+"))
  #show.units = "units" %in% show.modes;
  #show.networks = "network" %in% show.modes;

  #unit.group_by <- match.arg(unit.group_by);
  #estimate.network.over <- match.arg(estimate.network.over);

  return(plot);
}
