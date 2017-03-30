#######
#' ENAdata R6class
#' @docType class
#' @importFrom R6 R6Class
#' @export
#' @usage ENAdata$new(...)
#'
#' @param file CSV, data.frame, or data.table
#' @param unitsBy String vector representing column names to use for units
#' @param units String vector of which units to include in the ENAset
#' @param conversationsBy String vector of column names to create the conversations
#' @param codeNames String vector of column names to use as codes
#' @param windowSize Integer used to select the size of each stanza window within a conversation
#' @param binary Logical, whether to convert code values to binary or allow for weigthed values
#' @param unitsSelected deprecated
#'
#' @section Public ENAdata methods:
#######
ENAdata = R6::R6Class("ENAdata",
  public = list(

    #######
    ### Constructor - documented in main class declaration
    #######
    initialize = function(
      file,
      unitsBy = NULL, units = NULL,
      conversationsBy = NULL,
      codeNames = NULL,
      windowSize = 1,
      binary = T,
      unitsSelected = NULL,
      units.exclude = c(),
      ...
    ) {
      private$file <- file;
      private$unitsBy <- unitsBy;
      private$units <- units;
      private$unitsSelected <- unitsSelected;
      private$conversationsBy <- conversationsBy;
      private$codeNames <- codeNames;
      private$windowSize <- windowSize;
      private$binary <- binary;
      private$units.exclude <- units.exclude;
      self$data <- private$loadFile();

      self
    },

    #######
    ### Public Properties
    #######
    data = NULL,

    #####################
    ## Public Functions
    #####################
    #' \code{get()} - Return a read-only property
    #' \preformatted{  Example:
    #'     get( x = 'file' )}
    #' \preformatted{  Parameters:
    #'      x - Property to return. Defaults to 'file', returning the original data}
    #######
    get = function(x = "data") return(private[[x]]),

    #######
    #' \code{read()} - Return the accumulated data
    #' \preformatted{  Example:
    #'     get( colnames = T, sep = " & " )}
    #' \preformatted{  Parameters:
    #'      colnames - Logical, whether to replace colnames with their names values from the adjacency matrix
    #'      sep - String to use as a seperator in the updated column names. Ignored if colnames == F}
    #######
    read = function(colnames = T, sep = " & ") {
      namedData = data.table::copy(self$data);
      if(colnames == T) {
        namedRows = attr(self$data, "adjacency.matrix");
        #colnames(namedData) = c("ENA_UNIT", apply(namedRows, 2, function(x) paste(x[1], x[2], sep=sep)));
        colnames(namedData)[grep("adjacency.code",colnames(namedData))] = apply(namedRows, 2, function(x) paste(x[1], x[2], sep=sep))
      }
      namedData
    },

    ########
    #' \code{update()} - Change any of the allowed properties then reprocess the ENAdata.
    #' \preformatted{  Example:
    #'     update(
    #'       file = private$file,
    #'       codeNames = private$codeNames,
    #'       conversationsBy = private$conversationsBy,
    #'       units = private$units,
    #'       unitsSelected = private$unitsSelected,
    #'       windowSize = private$windowSize,
    #'       reload = FALSE
    #'       ...
    #'     )}
    #' \preformatted{  Parameters:
    #'     file - The original data to accumulate, as a data.frame or data.table
    #'     codeNames - String vector of column names to use as codes
    #'     conversationsBy - String vector of column names to create the conversations
    #'     units - String vector of which units to include in the ENAset
    #'      windowSize - Integer used to select the size of each stanza window within a conversation
    #'     reload - Logical, force reloading of the ENAdata object}
    #######
    update = function(
      file = private$file,
      codeNames = private$codeNames,
      conversationsBy = private$conversationsBy,
      units = private$units,
      units.exclude = private$units.exclude,
      windowSize = private$windowSize,
      reload = F
    ) {
      if(all.equal.raw(file, private$file) == FALSE) {
        private$file <- file; reload = T;
      }
      if( identical(codeNames, private$codeNames) == F ) {
        private$codeNames <- codeNames; reload = T;
      }
      if( is.null(units) || !all(units == private$units) ) {
        private$units <- units; reload = T;
      }
      if( identical(units.exclude, private$units.exclude) == F ) {
        private$units.exclude <- units.exclude; reload = T;
      }
      if( is.null(conversationsBy) || !all(conversationsBy == private$conversationsBy) ) {
        private$conversationsBy <- conversationsBy; reload = T;
      }
      if( identical(windowSize, private$windowSize) == F) {
        private$windowSize = windowSize; reload = T;
      }

      if(reload == T) self$data <- private$loadFile();

      return(self);
    }
  ),

  #######
  ### Private
  #######
  private = list(

    #######
    ### Private Properties
    #######
    file = NULL,
    windowSize = 1,
    unitsList = NULL,
    unitsBy = NULL,
    units = NULL,
    unitsSelected = NULL,
    conversationsBy = NULL,
    codeNames = NULL,
    binary = T,
    units.exclude = c(),

    #######
    ### Private Functions
    #######
    loadFile = function() {
      if(any(class(private$file) == "data.table")) {
        df_DT = df;
      } else {
        if(class(private$file) == "data.frame") {
          df = private$file;
        } else {
          df = read.csv(private$file);
        }
        df_DT = data.table::as.data.table(df);
      }

      newRes = accumulate.data(
        dfDT = df_DT,
        stanzasBy = private$conversationsBy,
        unitsBy = private$unitsBy,
        units = private$units, #private$units,
        unitsSelected = private$unitsSelected,
        codeNames = private$codeNames,
        window = private$windowSize,
        binary = private$binary,
        units.exclude = private$units.exclude
      );

      return(newRes);
    }
  )
)
