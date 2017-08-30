

ena.plot <- function(
  enaset,

  title = "ENA Plot",

  dimensions = c(1,2),
  dimension.labels = c("X","Y"),
  dimension.show.variance = T,

  end.points = F,

  flip.axis.x = F,
  flip.axis.y = F,

  font.size = 10,
  font.color = "000000",
  font.family = "Arial",

  ...
) {
  plot = ENAplot$new(enaset,
           title = title,
           dimensions = dimensions,
           dimension.labels = dimension.labels,
           dimension.show.variance = dimension.show.variance,
           end.points = end.points,
           flip.axis.x = flip.axis.x,
           flip.axis.y = flip.axis.y,
           font.size = font.size,
           font.color = font.color,
           font.family = font.family,
           ...
  );
  return(plot);
}
