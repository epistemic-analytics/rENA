####
#' ENAset R6class
#'
#' @docType class
#' @importFrom R6 R6Class
#' @import data.table
#' @export
#'
# @param enadata ENAdata Object
# @param dims Number of dimensions
# @param samples Number of samples
# @param inPar Peform in parallel
# @param binary Binary or Weighted
# @param correction Function to perform weighted correction
# @param norm.by Function to sphere normalize.  Provided:\cr
#   \code{dont_sphere_norm_c} - Default\cr
#   \code{sphere_norm_c}
# @param center.data Function to center data. Provided:\cr
#   \code{center_data_c} - Default
# @param optim.method Function to optimize node positions. Provided:\cr
#   \code{do_optimization} - Default\cr
#   \code{do_optimization_2}
# @param node.position.method [TBD]
# @param check.unique.positions Check for uniqueness in positions
# @param set.seed Force uniqueness across function calls, e.g - set.seed=42\cr Defaults to FALSE
# @param rotate.means [TBD]
# @param rotate.means.by [TBD]
#'
#' @section Public ENAset methods:
####

ENAset = R6::R6Class("ENAset",

  public = list(

    ####
    ### Constructor - documented in main class declaration
    ####
    initialize = function(
      enadata,
      dimensions = 2,

      norm.by = sphere_norm_c,

      rotation.by = ena.svd,
      rotation.params = NULL,
      rotation.set = NULL,

      #center.data = center_data_c,    ### made local to run
      node.position.method = lws.positions.es,

      endpoints.only = T,

      ### NOT PARAMS OF ena.make.set
      set.seed = F,    #### used in do_optimization
      rotate.means = F,
      rotate.means.by = NULL,

      ...
    ) {
      self$enadata <- enadata;

      private$dimensions <- dimensions;

      #private$samples <- samples;
      #private$inPar <- inPar;

      ### new rotation properties

      #old rotation properties
      private$set.seed <- set.seed;

      private$rotate.means <- rotate.means;
      private$rotate.means.by <- rotate.means.by;
      ###

      #CHECK FORMAT
      #self$unit.names <- as.matrix(enadata$adjacency.vectors[,1])[,1];

      self$codes <- enadata$codes;

      self$rotation.set <- rotation.set;

      self$function.call <- sys.call();

      self$function.params$norm.by <- norm.by;    #was sphere_norm
      #self$function.params$center.data <- center.data;
      self$function.params$node.position.method <- node.position.method;    #was position.method
      self$function.params$rotation.by <- rotation.by;
      self$function.params$rotation.params <- rotation.params;
      self$function.params$endpoints.only <- endpoints.only;

    },

    ####
    ## Public Properties
    ####

    #unit.names = NULL,


     #####changed to list - function.params
    # check.unique.positions = NULL,
    # optim.method = NULL,
    # norm.by = NULL,
    # center.data = NULL,
    # position.method = NULL,

    #data = list(
      #original = NULL,   ### changed to private (data.original)
      #raw = NULL,    # -> points.raw
      #normed = NULL, # -> line.weights
      #centered = list(
      #  normed = NULL,    # -> points.normed.centered
      #  rotated = NULL    # -> points.rotated
      #),
      #optim = NULL    #### USED IN egr.positions - replaced w/ temporary variable in function
    #),

    #nodes = list(
    #  positions = list(
    #    optim = NULL,    #### (contains correlation) optim$correlation ->correlation (possibly also variance)
    #    unscaled = NULL  #going to be removed - currently used in egr.positions
    #    scaled = NULL   #### -> node.positions
    #  )
    #),

    rotation_dists = NULL,  #leave for now - to be removed for a temp variable

    #######   NEW PUBLIC PROPERTIES
    enadata = NULL,

    points.raw = NULL,    #was data$raw
    points.normed.centered = NULL,    #was data$centered$normed
    points.rotated = NULL,    #was data$centered$rotated
    points.rotated.non.zero = NULL,

    line.weights = NULL,   #was data$normed
    line.weights.non.zero = NULL,
    line.weights.unrotated = NULL,

    #### NEW
    node.positions = NULL,  #was nodes$positions$scaled

    codes = NULL,

    rotation.set = NULL,   ## new - ENARotation object

    correlation = NULL,   #not formerly listed, comes from optimized node positions in egr.positions
    variance = NULL,     #was self$data$centered$latent

    function.call = NULL,     #new - string reping function call
    function.params = list(   #list containing parameters function was called with
      norm.by = NULL,
      node.position.method = NULL,
      rotation.by = NULL,
      rotation.params = NULL,
      endpoints.only = NULL
    ),

    ####
    ## Public Functions
    ####
    asJSON = function() {
      return( list() )
    },

    ####
    #' \code{update()} - Change any of the allowed properties then reprocess the ENAset.
    #' \preformatted{  Example:
    #'     update(
    #'       x="set",
    #'       data=self$enadata,
    #'       dims=private$dimensions,
    #'       samples=private$samples,
    #'       ...
    #'     )}
    #' \preformatted{  Parameters:
    #'     x - Update this 'ENAset' or its 'ENAdata' object. Default is 'set'
    #'     data - ENAdata object
    #'     dims - Number of dims
    #'     samples - Number of samples
    #'     ... - Extra parameters passed to 'ENAdata$update()'}
    ####
    update = function(
      x = "set",
      data = self$enadata,
      dims = private$dimensions,
      samples = private$samples,
      ...
    ) {
      if(x == "set") {
        self$enadata <- data;
        private$dimensions <- dims;
        private$samples <- samples;
      } else if (x == "data") {
        self$enadata <- self$enadata$update(...);
      }

      #self$unit.names <- as.matrix(enadata$adjacency.vectors[,1])[,1];
      self$codes <- enadata$get("codes");

      return(self$process());
    },

    ####
    #' \code{process()} - Process the ENAset.
    #' \preformatted{}
    ####
    process = function() {
      return(private$run())
    },

    ####
    get.data = function(wh = c("normed","centered","rotated"), with.meta = T) {
      wh =  match.arg(wh);
      data = NULL;
      if( wh == "normed" ) {
        data = self$line.weights
      } else if ( wh == "centered" ) {
        data = self$points.normed.centered
      } else if ( wh == "rotated" ) {
        data = self$points.rotated
      }
      df.to.return = NULL;
      if(with.meta == T) {
        data.units = attr(data, rENA::opts$UNIT_NAMES);
        df.to.return = cbind(
          data.table::data.table(
            data, data.units,
            ENA_UNIT=merge_columns_c(data.units, self$enadata$get("units.by")),
            TRAJ_UNIT=merge_columns_c(data.units, c(self$enadata$get("units.by"), self$enadata$get("trajectory.by")))
          ),
          self$enadata$add.metadata()
        )
      } else {
        df.to.return = data
      }
      df.to.return
    },

    ####
    #' \code{rotate()} - Rotate the centered data by the provided rotation matrix
    #' \preformatted{  Example:
    #'    rotate(rotation = self$data$centered$pca)}
    #' \preformatted{  Parameters:
    #'    rotation - Defaults to ENAdata$centered$pca}
    ####
    # rotate = function(rotation = self$data$centered$pca) {
    #   return(private$rotateNodes(rotation))
    # },


    ####
    #' \code{get()} - Return a read-only property
    #' \preformatted{  Example:
    #'     get( x = 'file' )}
    #' \preformatted{  Parameters:
    #'      x - Property to return. Defaults to 'file', returning the original data}
    ####
    get = function(x = "enadata") {
      return(private[[x]])
    },

    ####
    #' \code{plot()} - Plot ENAset node locations.
    #' \preformatted{  Example:
    #'     plot(
    #'       wh = 'nodes',
    #'       hide = NULL,
    #'       name.units.by = NULL,
    #'       name.units.sep = ".",
    #'       ...
    #'     )}
    #' \preformatted{  Parameters:
    #'      wh - What to plot: "nodes" or "units"
    #'      hide - Vector of items to hide from plot
    #'      name.units.by - Vector of string column names to use as labels
    #'      name.units.sep - Charcter used to join multiple columns as a label
    #'      ... - Parameters passed on to `plotly`}
    ####
    plot = function(
      wh = "nodes",
      hide = NULL,
      name.units.by = NULL,
      name.units.sep = ".",
      ...
    ) {
      x = NULL;
      y = NULL;
      labels = NULL;
      col = 0;

      if ( wh == "network" ) {
        ena.plot.network(self, ...);
      } else {
        if(wh == "nodes") {
          rotDF = as.data.frame(data.table::copy(self$node.positions));
          rotDF$unit = rownames(self$node.positions);
        } else if ( wh == "units" ) {
          rotDF = as.data.frame(data.table::copy(self$points.rotated));

          if(!is.null(name.units.by)) {
            rotDF$unit = attr(self$points.rotated, rENA::opts$UNIT_NAMES)[,{apply(.SD,1,function(x){paste(trimws(x),collapse=name.units.sep)})},with=T,.SDcols=name.units.by];
          } else {
            rotDF$unit = rownames(rotDF);
          }
        } else if ( wh == "network" ) {
          ena.plot.network(self, ...)
        }

        if(!is.null(hide)) {
          rotDF = rotDF[!rotDF$unit %in% hide,]
        }

        p = plotly::plot_ly(
          type = "scatter", data = rotDF,
          x = ~V1, y = ~V2,
          text = ~unit,
          mode = "markers",
          showlegend = F,
          ...
        );
        return(p)
      }
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

  private = list(
    ####
    ## Private Properties
    ####

    #new
    data.original = NULL,
    optim = NULL,

    #moved from public
    dimensions = 2,
    samples = 3,
    inPar = FALSE,

    N = NULL,
    n1 = NULL,
    n2 = NULL,
    K = NULL,
    k1 = NULL,
    k2 = NULL,

    ### TO BE REMOVED ONCE NEW ROTATION ALGORITHM IMPLEMENTED
    set.seed = F,
    rotate.means = F,
    rotate.means.by = NULL,
    ###

    ####
    ## Private Functions
    ####
    run = function() {
      # Reference for the ENAdata object
      df = self$enadata$metadata;
      ###
      # Backup of ENA data, this is not touched again.
      ###
      private$data.original = df[,grep("adjacency.code", colnames(df)), with=F]

      ###
      # Copy of the original data, this is used for all
      # further operations. Unlike, `data.original`, this
      # is likely to be overwritten.
      ###
      self$points.raw = data.table::copy(private$data.original);

      ###
      # Normalize the raw data using self$function.params$norm.by,
      # which defaults to calling rENA::dont_sphere_norm_c
      ###
      self$line.weights = self$function.params$norm.by(self$points.raw);

      ##
      # Convert the string vector of code names to their corresponding
      # co-occurence names and set as colnames for the self$line.weights
      ##
      codeNames_tri = svector_to_ut(self$enadata$codes);
      colnames(self$line.weights) = codeNames_tri;
      # set the rownames to that of the original ENAdata file object
      rownames(self$line.weights) = rownames(df);
      attr(self$line.weights, rENA::opts$UNIT_NAMES) = attr(df, rENA::opts$UNIT_NAMES) #df[, .SD, with=T, .SDcols=self$enadata$get("unitsBy")];
      ###

      ###
      # Remove the zeroed rows
      #  - Used specifically when performing the optimization
      ###
      self$line.weights.non.zero = remove_zero_rows_c(self$line.weights);
      ###

      ###
      # Store the indices of the upper-triangle for use in selecting the
      # values directly from vectors later on. Avoids having to create
      # larger, under-used matrices.
      ###
      private$N = getN(self$line.weights.non.zero);
      private$K = getK(self$line.weights.non.zero);
      private$n1 = triIndices(private$N, 0) + 1;
      private$n2 = triIndices(private$N, 1) + 1;
      private$k1 = triIndices(private$K, 0) + 1;
      private$k2 = triIndices(private$K, 1) + 1;
      ###


      ###
      # Center the normed data
      # FIX - store as $data$centered
      ###
      #### ISSUE
      #print(self$function.params$center.data)
      self$points.normed.centered = center_data_c(self$line.weights);

      colnames(self$points.normed.centered) = codeNames_tri;
      rownames(self$points.normed.centered) = rownames(df);
      attr(self$points.normed.centered, rENA::opts$UNIT_NAMES) = attr(self$line.weights, rENA::opts$UNIT_NAMES)
      ###

      ###
      # Means Rotations
      ###

      #######NEW ROTATION FUNCTION

      ### FOR TESTING
      # rotation.by = list(
      #   c(FUN = "ena.rotate.by.mean", list("Condition" = c("A","B"), "group" = c("1","2"))),
      #   c(FUN = "orthogonal.svd")
      # )
      #print(df.set$line.weights)
      # ### END TESTING CODE
      #
      # if no rotation set provided, construct one using the parameters in rotation.by

       # if(is.null(self$rotation)) {
      #   for(vector in rotation.by) {
      #
      #     this.function = vector$FUN
      #     this.params = vector[2];
      #
      #     self$rotation = do.call(this.function, list(df.set$line.weights, this.params))
      #
      #   }
      # ### else use provided Rotation Set
      # } else {
      #
      # }
      #
      # print(df.set$line.weights)

      ###### END NEW ROTATION

      if(!is.null(self$function.params$rotation.by)) {
        self$rotation.set = do.call(self$function.params$rotation.by, list(self, self$function.params$rotation.params))
      }


      ###OLD ROTATION
      # if(private$rotate.means == T) {
      #   #for(group in names(private$rotate.means.by)) {
      #   self$line.weights.unrotated = self$line.weights;
      #       ### used to be  self$data$centered$pca
      #   self$rotation.set = ena.rotate.by.mean(self$line.weights, private$rotate.means.by); #[[group]]);
      #   #}
      # }

      ###
      # Principal Component results
      ###
      # else {
      #   to.norm = data.table::data.table(
      #     self$points.normed.centered,
      #     merge_columns_c(
      #       attr(
      #         self$points.normed.centered,
      #         rENA::opts$UNIT_NAMES
      #       ),
      #       self$enadata$get("units.by")
      #     )
      #   )
      #   to.norm = as.matrix(to.norm[,tail(.SD,n=1),.SDcols=colnames(to.norm)[which(colnames(to.norm) != "V2")],by=c("V2")][,2:ncol(to.norm)]);
      #   pcaResults = pca_c(to.norm, dims = private$dimensions);
      #   ### used to be  self$data$centered$pca
      #   self$rotation.set = pcaResults$pca;
      #   ### used to be self$data$centered$latent
      #   self$variance = pcaResults$latent[private$dimensions];
      # }
      ###

      ###
      # Generated the rotated points
      ###
      self$points.rotated = self$points.normed.centered %*% self$rotation.set$rotation;
      attr(self$points.rotated, rENA::opts$UNIT_NAMES) = attr(self$points.normed.centered, rENA::opts$UNIT_NAMES);
      ###

      ###
      # Remove zero rows from centered data
      ###
      self$points.rotated.non.zero = remove_zero_rows_by_c(self$points.rotated, indices=self$line.weights);
      ###

      self = self$function.params$node.position.method(self);

      return(self);
    }

  )
)
