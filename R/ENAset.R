#######
### ENA set class
#######
ENAset = R6Class("ENAset",

  public = list(
    #######
    ### Constructor
    #######
    initialize = function(
      enaData,
      dims=2,
      samples=3,
      optimMethod="C",
      inPar=F,
      codeColumns=NULL,
      sphereNorm=T,
      binary=T,
      correction=0,
      ...
    ) {
      private$enaData <- enaData;
      private$dimensions <- dims;
      private$samples <- samples;
      private$optimMethod <- optimMethod;
      private$inPar <- inPar;
      private$codeColumns <- codeColumns;
      private$sphereNorm <- sphereNorm;
      private$binary <- binary;
      private$correction <- correction;
    },

    #######
    ### Public Properties
    #######
    data = list(
      raw = NULL,
      normed = NULL,
      centered = list(
        rotated = NULL
      ),
      optim = NULL
    ),
    nodes = list(
      positions = list(
        optim = NULL,
        rotated = NULL
      )
    ),
    rotation_dists = NULL,

    #######
    ### Public Functions
    #######
    update = function(data = private$enaData, dims = private$dimensions, ...) {
      private$enaData <- data;
      private$dimensions <- dims;

      return(self$process());
    },
    process = function() return(private$run()),
    get = function(x) return(private[[x]])
  ),

  private = list(
    #######
    ### Private Properties
    #######
    enaData = NULL,
    dimensions = 2,
    samples = 3,
    optimMethod = "C",
    inPar = FALSE,
    codeColumns = NULL,
    binary = T,
    sphereNorm = T,
    correction = 0,

    #######
    ### Private Functions
    #######
    run = function() {
      df = private$enaData$get();
      by_num = length(private$enaData$get("unitsBy"));

      codeNames_tri = svector_to_ut(private$enaData$get("codeNames"));

      #browser();
        self$data$raw = df[,(by_num+1):ncol(df), with=F];
      #if(is.null(private$codeColumns)) {
      #} else {
      #  self$data$raw = df[,private$codeColumns, with=F];
      #}

      self$data$raw.corrected = self$data$raw;
      if(private$binary == F) {
        if(private$correction == 1) {
          self$data$raw.corrected = log(self$data$raw + 1);
        } else if(private$correction == 2) {
          self$data$raw.corrected = sqrt(self$data$raw);
        }
      }

      if(private$sphereNorm == T) {
        self$data$normed = sphere_norm(data.matrix(self$data$raw.corrected));
      } else {
        self$data$normed = dont_sphere_norm(data.matrix(self$data$raw.corrected));
      }

      #colnames(self$data$normed) = codeNames_tri;

      self$data$centered$normed = centerData(self$data$normed);
      #colnames(self$data$centered$normed) = codeNames_tri;

      self$data$centered$pca = pca(self$data$centered$normed, dims = private$dimensions);
      self$data$centered$rotated = centerDataRotated(self$data$centered$normed, self$data$centered$pca);
      self$rotation_dists = getRotationDistances(self$data$centered$rotated);

      if(private$optimMethod == "C") {
        self$data$optim = do_optimization_2(self, inPar = private$inPar);
      } else {
        self$data$optim = do_optimization(self, inPar = private$inPar);
      }

      self$nodes$positions$optim = get_optimized_node_pos(self$data$normed, private$dimensions, private$samples, opted = self$data$optim);

      self$nodes$positions$rotated = full_opt(normed = self$data$normed, rotated = self$data$centered$rotated, optim_nodes = self$nodes$positions$optim, dims = private$dimensions);

      return(self);
    }
  )
)
