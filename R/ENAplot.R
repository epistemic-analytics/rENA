####
#' ENAset R6class
#'
#' @docType class
#' @importFrom R6 R6Class
#' @import data.table
#' @export
#'
# @param enaset ENAplot Object
#
# @param
#'
#' @section Public ENAplot methods:
####

ENAplot = R6::R6Class("ENAplot",

  public = list(

    ####
    ### Constructor - documented in main class declaration
    ####
    initialize = function(
      enaset = NULL,

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

      self$enaset <- enaset;
      self$plot <- plot_ly(
         mode = "markers",
         type ="scatter"
       )

      private$title <- title;
      private$dimensions <- dimensions;
      private$dimension.labels <- dimension.labels;
      private$dimension.show.variance <- dimension.show.variance;
      private$end.points <- end.points;
      private$flip.axis.x <- flip.axis.x;
      private$flip.axis.y <- flip.axis.y;
      private$font.size <- font.size;
      private$font.color <- font.color;
      private$font.family <- font.family;

    },

    ####
    ## Public Properties
    ####

    enaset = NULL,

    plot = NULL,

    ####
    ## Public Functions
    ####
    print = function() {
      print(self$plot);
    },

    ####
    #' \code{get()} - Return a read-only property
    #' \preformatted{  Example:
    #'     get( x = 'title' )}
    #' \preformatted{  Parameters:
    #'      x - Property to return. Defaults to 'title', returning the title}
    ####
    get = function(x) {
      return(private[[x]])
    }

  ),

  private = list(

    ####
    ## Private Properties
    ####
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

    #plot.color = I("black"),

    multiplier = 5

    ####
    ## Private Functions
    ####

  )
)
