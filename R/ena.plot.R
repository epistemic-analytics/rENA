##
#' @title Generate ENA Plot
#'
#' @description Generates an ENA Plot from a given ENA set object.
#'
#' @details This function processes an ENAset, generating an ENAplot object that can be analyzed or used to plot aspects of the set.
#'
#' @export
#'
#' @param enaset \code{\link{ENAset}} that will be used to generate an ENA plot
#' @param title character - title for the plot, default: “ENA Plot”
#' @param dimensions Number of dimensions to be in the plot, numeric vector - default: c(1,2)
#' @param dimension.labels	character vector - labels for axes, default: c(“X”, “Y”)
#' @param dimension.show.variance
#' @param end.points logical - determines whether to only show endpoints for trajectory models
#' @param flip.axis.x		logical - ?, default: false
#' @param flip.axis.y		logical - ?, default: false
#' @param font.size		integer - size of font for graph labels, default:
#' @param font.color		character - color of label font, default: “black”
#' @param font.family		character - font type, choices: Arial, Courier New, Times New Roman, default: “Arial”
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
