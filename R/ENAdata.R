####
#' ENAdata R6class
#'
#' @docType class
#' @importFrom R6 R6Class
#' @import data.table
#' @export
#'
# @param file CSV, data.frame, or data.table
# @param units String vector representing column names to use for units --- FORMERLY units.by  ####OLD
# @param units data frame with unit columns and values #### NEW
# @param units.by String vector of which units to include in the ENAset --- FORMERLY units
# @param conversation String vector of column names to create the conversations --- FORMERLY conversations.by
# @param codes String vector of column names to use as codes
# @param window.size Integer used to select the size of each stanza window within a conversation
# @param window.size.back [TBD]
# @param window.size.forward [TBD]
# @param weight.by string or function determining to convert codes to binary, allow weighted, or apply a correcion
# @param binary Logical, whether to convert code values to binary or allow for weigthed values  --- NO LONGER INCLUDED
# @param correction math operation by which to modify data for weighted values (i.e. log, sqrt) --- NO LONGER INCLUDED
# @param units.selected deprecated
# @param units.exclude [TBD]
# @param model - type of ENA model: endpoint or trajectory, if trajectory what type
# @param trajectory.by [TBD]
# @param trajectory.type [TBD]
#'
#' @section Public ENAdata methods:
####
ENAdata = R6::R6Class("ENAdata",
  public = list(

    ####
    ## Constructor - documented in main class declaration
    ####
    initialize = function(
      file,    #csv or data frame containing units, codes, conversations, and metadata

      units = NULL,     #data frame of unit columns and values
      units.used = NULL,    #vector of unit values to include (a subset of rows of the units df)

      units.by = NULL,  # unit col names that will be grouped by to determine ENA_UNIT

      conversations.by = NULL,   # conversation col names that will be grouped by to determine conversations

      codes = NULL,  #vector of code column names to use in accumulation

      window.size = 1,
      window.size.back = window.size,
      window.size.forward = NULL,

      weight.by = "binary",

      units.selected = NULL,
      units.exclude = c(),

      model = NULL,
      trajectory.by = NULL,
      ...
    ) {
      self$function.call <- sys.call(-1);

      private$file <- file;

      self$units <- units;

      private$units.used <- units.used;

      private$units.by <- units.by
      private$conversations.by <- conversations.by;

      private$trajectory.by <- trajectory.by;
      if(is.null(trajectory.by)) private$trajectory.by = conversations.by;

      self$codes <- codes;
      if(is.data.frame(self$codes)) self$codes <- colnames(self$codes);

      private$window.size <- list(
        "back" = window.size.back,
        "forward" = window.size.forward
      );

      private$weight.by <- weight.by;

      private$units.exclude <- units.exclude;

      self$model <- model;

      if(self$model == "EndPoint") private$trajectory.by <- NULL;

      private$loadFile();

      self
    },

    ####
    ## Public Properties
    ####

    ##### OLD
    #function.call = NULL,  #remains
    #data.raw = NULL,  # -> raw
    #data.units.summed = NULL, # -> adjacency.vectors
    #data.units.accumulated = NULL, # -> accumulated.adjacency
    #data.units.summed.meta = NULL, # -> metadata
    #data.units.summed.raw = NULL, # -> adjacency.vectors.raw (saved before applying correction)

    model = NULL,

    raw = NULL,

    adjacency.vectors = NULL,
    accumulated.adjacency.vectors = NULL,
    adjacency.vectors.raw = NULL,

    units = NULL,
    units.names = NULL,

    metadata = NULL,

    trajectories.unit = NULL,
    trajectories.step = NULL,
    trajectories.point.names = NULL,

    codes = NULL,

    function.call = NULL,
    function.params = NULL,

    ####
    ## Public Functions
    ####
    #' \code{get()} - Return a read-only property
    #' \preformatted{  Example:
    #'     get( x = 'file' )}
    #' \preformatted{  Parameters:
    #'      x - Property to return. Defaults to 'file', returning the original data}
    ####
    get = function(x = "data") {
      return(private[[x]])
    },

    ####
    #' \code{read()} - Return the accumulated data
    #' \preformatted{  Example:
    #'     get( colnames = T, sep = " & " )}
    #' \preformatted{  Parameters:
    #'      colnames - Logical, whether to replace colnames with their names values from the adjacency matrix
    #'      sep - String to use as a seperator in the updated column names. Ignored if colnames == F}
    ####
    read = function(colnames = T, sep = " & ") {
      namedData = data.table::copy(self$data.units.accumulated);
      if(colnames == T) {
        namedRows = attr(self$data.units.accumulated, "adjacency.matrix");
        #colnames(namedData) = c("ENA_UNIT", apply(namedRows, 2, function(x) paste(x[1], x[2], sep=sep)));
        colnames(namedData)[grep("adjacency.code",colnames(namedData))] = apply(namedRows, 2, function(x) paste(x[1], x[2], sep=sep))
      }
      namedData
    },

    ####
    #' \code{update()} - Change any of the allowed properties then reprocess the ENAdata.
    #' \preformatted{  Example:
    #'     update(
    #'       file = private$file,
    #'       codes = self$codes,
    #'       conversations.by = private$conversations.by,
    #'       units = self$units,
    #'       unitsSelected = private$unitsSelected,
    #'       windowSize = private$windowSize,
    #'       reload = FALSE
    #'       ...
    #'     )}
    #'
    #' \preformatted{  Parameters:
    #'     file - The original data to accumulate, as a data.frame or data.table
    #'     codes - String vector of column names to use as codes
    #'     conversations.by - String vector of column names to create the conversations
    #'     units - String vector of which units to include in the ENAset
    #'      windowSize - Integer used to select the size of each stanza window within a conversation
    #'     reload - Logical, force reloading of the ENAdata object}
    ####
    update = function(
      file = private$file,
      codes = self$codes,
      conversations.by = private$conversations.by,
      units = self$units,
      units.exclude = private$units.exclude,
      windowSize = private$windowSize,
      reload = F
    ) {
      if(all.equal.raw(file, private$file) == FALSE) {
        private$file <- file; reload = T;
      }
      if( identical(codes, self$codes) == F ) {
        self$codes <- codes; reload = T;
      }
      if( is.null(units) || !all(units == self$units) ) {
        self$units <- units; reload = T;
      }
      if( identical(units.exclude, private$units.exclude) == F ) {
        private$units.exclude <- units.exclude; reload = T;
      }
      if( is.null(conversations.by) || !all(conversations.by == private$conversations.by) ) {
        private$conversations.by <- conversations.by; reload = T;
      }
      if( identical(windowSize, private$windowSize) == F) {
        private$windowSize = windowSize; reload = T;
      }

      if(reload == T) self$data <- private$loadFile();

      return(self);
    },

    add.metadata = function(merge = F) {
      ### get columns which arent in codes, units.by, or conversations.by
      metaAvail=colnames(self$raw)[-which(colnames(self$raw) %in% c(self$codes, private$units.by, private$conversations.by))];
      ### delimit possible metadata to only columns with one value per unit
      dfDT.meta.poss = self$raw[, { nc = lapply(.SD, function(x) length(unique(x))); }, by=c(private$units.by), .SDcols=c(metaAvail)][,,.SDcols=metaAvail];
      metaAvail = colnames(dfDT.meta.poss)[rapply(dfDT.meta.poss, function(x) all(x == 1))]
      metaAvail = metaAvail[metaAvail != "ENA_UNIT"];

      raw.meta = self$raw[!duplicated(ENA_UNIT)][ENA_UNIT %in% unique(self$accumulated.adjacency.vectors$ENA_UNIT),c("ENA_UNIT",private$units.by,private$trajectory.by, metaAvail),,with=F];

      df.to.return = NULL;
      if(merge == T) {
        df.to.return = merge(self$adjacency.vectors, raw.meta[,unique(colnames(raw.meta)),with=F], by=c("ENA_UNIT"), suffixes=c("",".y"))
      } else {
        df.to.return = merge(self$adjacency.vectors[,c("ENA_UNIT", private$trajectory.by),with=F],raw.meta,by=c("ENA_UNIT"), suffixes=c("","y"))
      }

      attr(df.to.return, rENA::opts$UNIT_NAMES) = df.to.return[,  .SD ,with=T,.SDcols=c(private$units.by,private$trajectory.by)];
      #self$adjacency.vectors[,  .SD ,with=T,.SDcols=c(private$units.by,private$trajectory.by)]

      df.to.return
    },
    print = function(...) {
      args = list(...);
      fields = NULL;
      to.print = list();
      if(is.null(args$fields)) {
        fields = names(get(class(self))$public_fields)
      } else {
        fields = args$fields
      }
      for(f in fields) {
        to.print[[f]] = self[[f]]
      }
      return(to.print);
    }
  ),

  ####
  ### Private
  ####
  private = list(

    ####
    ### Private Properties
    ####
    file = NULL,
    window.size = NULL,

    units.used = NULL,

    units.by = NULL,
    conversations.by = NULL,

    weight.by = NULL,

    units.exclude = NULL,

    trajectory.by = NULL,

    ####
    ### Private Functions
    ####
    loadFile = function() {
      if(any(class(private$file) == "data.table")) {
        df_DT = private$file;
      } else {
        if(any(class(private$file) == "data.frame")) {
          df = private$file;
        } else {
          df = read.csv(private$file);

          ###NEW LINE - taking unit cols of df, the columns specified in units.by (wasn't supplied if from csv)
          self$units = df[,private$units.by];

        }
        df_DT = data.table::as.data.table(df);
      }

      self$raw = df_DT;
      self$raw$ENA_UNIT = merge_columns_c(self$raw,private$units.by);

      self %<>% accumulate.data();

      # save raw adjacency vectors prior to corrections
      self$adjacency.vectors.raw = self$adjacency.vectors;

      # If weighted (not binary) and correction specified, invoke correction --- OLD VERSION
      # if(private$binary == F & !is.null(private$correction)) {
      #   cols = colnames(self$adjacency.vectors)[grep("adjacency.code", colnames(self$adjacency.vectors))];
      #   self$adjacency.vectors[, (cols) := lapply(.SD, private$correction), .SDcols = cols];
      # }
      #### NEW VERSION
      if(is.function(private$weight.by)) {
        cols = colnames(self$adjacency.vectors)[grep("adjacency.code", colnames(self$adjacency.vectors))];
        self$adjacency.vectors[, (cols) := lapply(.SD, private$weight.by), .SDcols = cols];
      }

      self$metadata = self$add.metadata(merge = T);

      return(self);
    }
  )
)
