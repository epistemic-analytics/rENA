##
#' @title Generate ENA Plot
#'
#' @description Generates an ENA Plot from a given ENA set object.
#'
#' @details This function processes an ENAset, generating an ENAplot object that can be analyzed or used to plot aspects of the set.
#'
#' @export
#'
#' @param enaset The \code{\link{ENAset}} that will be used to generate an ENA plot
#' @param title A character used for the title of the plot, default: ENA Plot
#' @param dimensions A numeric vector determining the number of dimensions to be in the plot, default: c(1,2)
#' @param dimension.labels A character vector containing labels for the axes, default: c(X, Y)
#' @param dimension.show.variance A logical indicating whether to show variance along the dimensions
#' @param end.points A logical variable that determines whether to only show endpoints for trajectory models
#' @param flip.axis.x	A logical - ?, default: false
#' @param flip.axis.y	A logical - ?, default: false
#' @param font.size An integer determining the font size for graph labels, default: 10
#' @param font.color A character, the color of label font, default: black
#' @param font.family A character, the font type, choices: Arial, Courier New, Times New Roman, default: Arial
#' @param ... additional parameters addressed in inner function
#'
#' @keywords ENA, generate, plot
#'
#' @seealso \code{\link{ena.make.set}}, \code{\link{ENAplot}}
#'
#' @examples
#' \dontrun{
#' #Given an \code{\link{ENAset}}
#' ena.plot(\code{\link{ENAset}})
#' }
#'
#' @return \code{\link{ENAplot}} can be used for plotting and other data analysis, final product of rENA model creation
##
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
  font.color = "#000000",
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
                     font.family,
                     ...
                     );

  return(plot);
}
