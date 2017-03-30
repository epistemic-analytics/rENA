########'
#' ENAset R6class
#'
#' @docType class
#' @importFrom R6 R6Class
#' @export
#' @usage ENAset$new()
#'
#' @param enaData ENAdata Object
#' @param dims Number of dimensions
#' @param samples Number of samples
#' @param inPar Peform in parallel
#' @param codeColumns Coded columns
#' @param binary Binary or Weighted
#' @param correction Function to perform weighted correction
#' @param sphere.norm Function to sphere normalize.  Provided:\cr
#'   \code{dont_sphere_norm_c} - Default\cr
#'   \code{sphere_norm_c}
#' @param center.data Function to center data. Provided:\cr
#'   \code{center_data_c} - Default
#' @param optim.method Function to optimize node positions. Provided:\cr
#'   \code{do_optimization} - Default\cr
#'   \code{do_optimization_2}
#' @param check.unique.positions Check for uniqueness in positions
#' @param set.seed Force uniqueness across function calls, e.g - set.seed=42\cr Defaults to FALSE
#'
#'
#' @section Public ENAset methods:
#######

ENAset = R6::R6Class("ENAset",

  public = list(

    #######
    ### Constructor - documented in main class declaration
    #######
    initialize = function(
      enaData,
      dims=2,
      samples=3,
      inPar=F,
      codeColumns=NULL,
      binary=T,
      correction=NULL,
      sphere.norm=dont_sphere_norm_c,
      center.data=center_data_c,
      optim.method=do_optimization,
      check.unique.positions=F,
      set.seed = F,
      ...
    ) {
      private$enaData <- enaData;
      private$dimensions <- dims;
      private$samples <- samples;
      private$inPar <- inPar;
      private$codeColumns <- codeColumns;
      private$binary <- binary;
      private$correction <- correction;
      private$set.seed <- set.seed;

      self$sphere.norm <- sphere.norm;
      self$center.data <- center.data;
      self$optim.method <- optim.method;
      self$check.unique.positions <- check.unique.positions;
    },

    #######
    ### Public Properties
    #######
    check.unique.positions = NULL,
    optim.method = NULL,
    sphere.norm = NULL,
    center.data = NULL,
    data = list(
      original = NULL,
      raw = NULL,
      normed = NULL,
      centered = list(
        normed = NULL,
        rotated = NULL
      ),
      optim = NULL
    ),
    nodes = list(
      positions = list(
        optim = NULL,
        unscaled = NULL,
        scaled = NULL
      )
    ),
    rotation_dists = NULL,

    #####################
    ## Public Functions
    #####################
    #' \code{update()} - Change any of the allowed properties then reprocess the ENAset.
    #' \preformatted{  Example:
    #'     update(
    #'       x="set",
    #'       data=private$enaData,
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
    #######
    update = function(
      x = "set",
      data = private$enaData,
      dims = private$dimensions,
      samples = private$samples,
      ...
    ) {
      if(x == "set") {
        private$enaData <- data;
        private$dimensions <- dims;
        private$samples <- samples;
      } else if (x == "data") {
        private$enaData <- private$enaData$update(...);
      }
      return(self$process());
    },

    #######
    #' \code{process()} - Process the ENAset.
    #' \preformatted{}
    #######
    process = function() return(private$run()),

    #######
    #' \code{rotate()} - Rotate the centered data by the provided rotation matrix
    #' \preformatted{  Example:
    #'    rotate(rotation = self$data$centered$pca)}
    #' \preformatted{  Parameters:
    #'    rotation - Defaults to ENAdata$centered$pca}
    #######
    rotate = function(rotation = self$data$centered$pca) return(private$rotateNodes(rotation)),

    #######
    #' \code{get()} - Return a read-only property
    #' \preformatted{  Example:
    #'     get( x = 'enaData' )}
    #' \preformatted{  Parameters:
    #'      x - Property to return. Defaults to 'enaData', returning the associated ENAdata object}
    #######
    get = function(x = 'enaData') return(private[[x]]),

    #######
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
    #######
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

      if(wh == "nodes") {
        rotDF = as.data.frame(data.table::copy(self$nodes$positions$scaled$positions));
        rotDF$unit = rownames(self$nodes$positions$scaled$positions);
      } else if ( wh == "units" ) {
        rotDF = as.data.frame(data.table::copy(self$data$centered$rotated));

        if(!is.null(name.units.by)) {
          rotDF$unit = attr(self$data$centered$rotated, UNIT_NAMES)[,{apply(.SD,1,function(x){paste(trimws(x),collapse=name.units.sep)})},with=T,.SDcols=name.units.by];
        } else {
          rotDF$unit = rownames(rotDF);
        }
      }

      if(!is.null(hide)) {
        rotDF = rotDF[!rotDF$unit %in% hide,]
      }

      p = plot_ly(
        type = "scatter", data = rotDF,
        x = ~V1, y = ~V2,
        text = ~unit,
        mode = "markers",
        showlegend = F,
        ...
      );
      return(p)
    }
  ),

  private = list(
    #######
    ### Private Properties
    #######
    enaData = NULL,
    dimensions = 2,
    samples = 3,
    inPar = FALSE,
    codeColumns = NULL,
    binary = T,
    correction = 0,
    N = NULL,
    n1 = NULL,
    n2 = NULL,
    K = NULL,
    k1 = NULL,
    k2 = NULL,
    set.seed = F,

    #######
    ### Private Functions
    #######
    run = function() {
      # Reference for the ENAdata object
        df = private$enaData$data;

      ###
      # Backup of ENA data, this is not touched again.
      ###
        #self$data$original = df[,(2):ncol(df), with=F];
        self$data$original = df[,grep("adjacency.code", colnames(df)), with=F]

      ###
      # Copy of the original data, this is used for all
      # further operations. Unlike, `data$original`, this
      # is likely to be overwritten.
      ###
        self$data$raw = data.table::copy(self$data$original);

      ###
      # If non-binary, invoke the supplied correction method
      # on the raw data.
      ###
      if(private$binary == F) {
        self$data$raw = private$correction(self$data$raw);
        # if(private$correction == 1) {
        #   self$data$raw = log(self$data$raw + 1);
        # } else if(private$correction == 2) {
        #   self$data$raw = sqrt(self$data$raw);
        # }
      }

      ###
      # Normalize the raw data using self$sphere.norm,
      # which defaults to calling rENA::dont_sphere_norm_c
      ###
        self$data$normed = self$sphere.norm(self$data$raw);

      ###
      # Convert the string vector of code names to their corresponding
      # co-occurence names and set as colnames for the self$data$normed
      ##
        codeNames_tri = svector_to_ut(private$enaData$get("codeNames"));
        colnames(self$data$normed) = codeNames_tri;
      # set the rownames to that of the original ENAdata file object
        rownames(self$data$normed) = rownames(df);
        attr(self$data$normed, UNIT_NAMES) = df[, .SD, with=T, .SDcols=private$enaData$get("unitsBy")];
      ###

      ###
      # Remove the zeroed rows
      #  - Used specifically when performing the optimization
      ###
        self$data$normed.non.zero = remove_zero_rows_c(self$data$normed);
      ###

      ###
      # Store the indices of the upper-triangle for use in selecting the
      # values directly from vectors later on. Avoids having to create
      # larger, under-used matrices.
      ###
        private$N = getN(self$data$normed.non.zero);
        private$K = getK(self$data$normed.non.zero);
        private$n1 = triIndices(private$N, 0) + 1;
        private$n2 = triIndices(private$N, 1) + 1;
        private$k1 = triIndices(private$K, 0) + 1;
        private$k2 = triIndices(private$K, 1) + 1;
      ###

      ###
      # Center the normed data
      ###
        self$data$centered$normed = self$center.data(self$data$normed);

        colnames(self$data$centered$normed) = codeNames_tri;
        rownames(self$data$centered$normed) = rownames(df);
        attr(self$data$centered$normed, UNIT_NAMES) = attr(self$data$normed, UNIT_NAMES)
      ###

      ###
      # Principal Component results
      ###
        pcaResults = pca_c(self$data$centered$normed, dims = private$dimensions);
        self$data$centered$pca = pcaResults$pca;
        self$data$centered$latent = pcaResults$latent;
      ###

      private$rotateNodes(self$data$centered$pca);

      return(self);
    },

    ###
    # Rotate by rotation matrix
    #
    # --The rotation args needs to conform to the data
    #   - Error in self$data$centered$normed %*% rotation:
    #       non-conformable arguments
    ###
    rotateNodes = function(rotation = self$data$centered$pca) {
      ###
      # Rotate the normed centered data by the pca results
      ###
        self$data$centered$rotated = self$data$centered$normed %*% rotation;
        attr(self$data$centered$rotated, UNIT_NAMES) = attr(self$data$centered$normed, UNIT_NAMES);
      ###

      ###
      # Remove zero rows from centered data
      ###
        self$data$centered$rotated.non.zero = remove_zero_rows_by_c(self$data$centered$rotated, indices=self$data$normed);
      ###

      ###
      # Calculate the rotation distances
      ###
        self$rotation_dists = getRotationDistances_c(self$data$centered$rotated.non.zero);
      ###

      ###
      # Perform the optimization
      ###
        self$data$optim = self$optim.method(self, inPar = private$inPar);
      ###

      ###
      # Store the optimized node positions
      ###
        self$nodes$positions$optim = get_optimized_node_pos_c(
          self$data$normed.non.zero, private$dimensions, private$samples, opted = self$data$optim
        );
      ###

      ###
      # Store the unscaled node positions
      ###
        self$nodes$positions$unscaled = full_opt_c(
          normed = self$data$normed.non.zero,
          rotated = self$data$centered$rotated.non.zero,
          optim_nodes = self$nodes$positions$optim,
          dims = private$dimensions, num_samples = private$samples
          ,checkUnique = self$check.unique.positions
        );
        rownames(self$nodes$positions$unscaled$positions) = private$enaData$get("codeNames");
      ###

      ###
      # Scale the node positions
      ###
        self$nodes$positions$scaled = full_opt_soln(
          self$nodes$positions$unscaled$positions,
          self$data$normed.non.zero,
          self$data$centered$rotated.non.zero
        );
        rownames(self$nodes$positions$scaled$positions) = private$enaData$get("codeNames")
      ###

      return(self);
    }
  )
)
