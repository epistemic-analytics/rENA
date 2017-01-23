#######
### ENA data class
#######
ENAdata = R6Class("ENAdata",
  public = list(

    #######
    ### Constructor
    #######
    initialize = function(
      file,
      unitsBy = NULL, units = NULL,
      unitsSelected = NULL,
      conversationsBy = NULL,
      codeNames = NULL,
      windowSize = 1,
      binary = T,
      exact.match = T,
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
      private$exact.match <- exact.match;
      #browser();
      private$data <- private$loadFile();
    },

    #######
    ### Public Functions
    #######
    get = function(x = "data") return(private[[x]]),
    update = function(
      file = private$file,
      codeNames = private$codeNames,
      conversationsBy = private$conversationsBy,
      units = private$units,
      unitsSelected = private$unitsSelected,
      reload = F
    ) {
      if(all.equal.raw(file, private$file) == FALSE) {
        private$file <- file; reload = T;
      }
      if( identical(unitsSelected, private$unitsSelected) == F) {
        private$unitsSelected <- unitsSelected; reload = T;
      }
      if( identical(codeNames, private$codeNames) == F ) {
        private$codeNames <- codeNames; reload = T;
      }
      if( is.null(units) || !all(units == private$units) ) {
        private$units <- units; reload = T;
      }
      if( is.null(conversationsBy) || !all(conversationsBy == private$conversationsBy) ) {
        private$conversationsBy <- conversationsBy; reload = T;
      }

      if(reload == T) private$data <- private$loadFile();

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
    data = NULL,
    windowSize = 1,
    unitsList = NULL,
    unitsBy = NULL,
    units = NULL,
    unitsSelected = NULL,
    conversationsBy = NULL,
    codeNames = NULL,
    binary = T,
    exact.match = T,

    #######
    ### Private Functions
    #######
    loadFile = function() {
      #browser()
      if(any(class(private$file) == "data.frame")) {
        df = private$file;
        df_DT = as.data.table(df);
      } else {
        df_DT = fread(private$file);
        df = as.data.frame(df_DT);
      }
      #df_DT = as.data.table(df);

      unitsListTable = data.frame(df[, private$unitsBy]);
      private$unitsList = unique(unitsListTable);
      colnames(unitsListTable) = private$unitsBy;

      unitsList = unitsListTable;

      #conversations = data.matrix(df[, private$conversationsBy]);

      #if(is.null(private$units)) {
      #  private$units = apply(as.matrix(as.matrix(unique(df[, colnames(unitsList)]), ncol=length(colnames(unitsList)))), 1, paste , collapse = ".");
      #}
      #browser();
      newRes = accumulate.data(
        dfDT = df,
        stanzasBy = private$conversationsBy,
        unitsBy = private$unitsBy,
        units = private$units, #private$units,
        unitsSelected = private$unitsSelected,
        codeNames = private$codeNames,
        window = private$windowSize,
        binary = private$binary,
        exact.match = private$exact.match
      );

      return(newRes);
    }
  )
)
