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

      plot.mode = "units+network",

      units = NULL,
      plot = NULL,

      units.by = NULL,

      font.size = 10,
      font.color = "000000",
      font.family = "Arial",

      #traces = NULL,

      ...
    ) {

      self$enaset <- enaset;
      self$plot <- plot_ly(
         mode = "markers",
         type ="scatter"
       )
      self$trajectory.by <- enaset$get("enaData")$get("trajectory.by");

      self$plot.mode <- plot.mode;
      self$units.by <- enaset$get('enaData')$get('units.by');

      private$units <- unique(enaset$get("enaData")$get("units"));

      #self$traces <- character(0);
    },

    ####
    ## Public Properties
    ####

    enaset = NULL,
    plot.mode = NULL,

    plot = NULL,

    plot.title = "ENA Plot",

    units.by = NULL,

    font.size = 10,
    font.color = "000000",
    font.family = "Arial",

    #traces = character(0),

    ####
    ## Public Functions
    ####
    print = function() {
      print(self$plot);
    }

  ),

  private = list(

    ####
    ## Private Properties
    ####

    plot.color = I("black"),

    dimensions = c(1,2),
    dimension.labels = c("x","y"),
    dimension.show.variance = T,
    multiplier = 5,

    ###re-introduced
    units = NULL


    ####
    ## Private Functions
    ####

  )
)
