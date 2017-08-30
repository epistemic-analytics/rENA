

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
  font.family = c("Arial", "Courier New", "Times New Roman"),

  ...
) {

  font.family = match.arg(font.family);

  plot = ENAplot$new(enaset,
                     title,
                     dimensions,
                     dimension.labels,
                     dimension.show.variance,
                     end.points,
                     flip.axis.x,
                     flip.axis.y,
                     font.size,
                     font.color,
                     font.family
                     );

  return(plot);
}
