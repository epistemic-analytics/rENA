##
#' @title Generate ENA Set
#'
#' @description Generates an ENA model by constructing a dimensional reduction of adjacency (co-occurrence) vectors in an ENA data object
#'
#' @details This function generates an ENAset object from an ENAdata object. Takes
#' the adjacency (co-occurrence) vectors from enadata, computes a dimensional
#' reduction (projection), and calculates node positions in the projected ENA
#' space. Returns location of the units in the projected space, as well as
#' locations for node positions, and normalized adjacency (co-occurrence) vectors
#' to construct network graphs
#'
#' @export
#'
#' @param enadata \code{\link{ENAdata}} that will be used to generate an ENA model
#' @param dimensions The number of dimensions to include in the dimensional reduction
#' @param norm.by A function to be used to normalize adjacency (co-occurrence) vectors before computing the dimensional reduction, default: sphere_norm_c()
#' @param rotation.by	A function to be used to compute the dimensional reduction, default: ena.svd()
#' @param rotation.params (optional) A character vector containing additional parameters for the function in rotation.by, if needed
#' @param rotation.set A previously-constructed  ENARotationSet object to use for the dimensional reduction
#' @param endpoints.only A logical variable which determines whether to only show endpoints for trajectory models
#' @param node.position.method A function to be used to determine node positions based on the dimensional reduction, default: lws.position.es()
#' @param ... additional parameters addressed in inner function
#'
#' @keywords ENA, generate, set
#'
#' @examples
#' data(RS.data)
#'
#' codeNames = c('Data','Technical.Constraints','Performance.Parameters',
#'   'Client.and.Consultant.Requests','Design.Reasoning','Collaboration');
#'
#' accum = ena.accumulate.data(
#'   units = RS.data[,c("UserName","Condition")],
#'   conversation = RS.data[,c("Condition","GroupName")],
#'   metadata = RS.data[,c("CONFIDENCE.Change","CONFIDENCE.Pre","CONFIDENCE.Post")],
#'   codes = RS.data[,codeNames],
#'   window.size.back = 4
#' )
#'
#' set = ena.make.set(
#'   enadata = accum
#' )
#'
#' set.means.rotated = ena.make.set(
#'   enadata = accum,
#'   rotation.by = ena.rotate.by.mean,
#'   rotation.params = list(
#'       accum$metadata$Condition=="FirstGame",
#'       accum$metadata$Condition=="SecondGame"
#'   )
#' )
#'
#' @seealso \code{\link{ena.accumulate.data}}, \code{\link{ENAset}}
#'
#' @return \code{\link{ENAset}} class object that can be further processed for analysis or plotting
##
ena.make.set <- function(
  enadata,
  dimensions = 2,
  norm.by = sphere_norm_c,
  rotation.by = ena.svd,
  rotation.params = NULL,
  rotation.set = NULL,
  endpoints.only = T,
  node.position.method = lws.positions.sq,
  ...
) {
  if("ENAdata" %in% enadata) {
    warning("Usage of ENAdata object will be deprecated and potentially removed altogether in future versions. See ena.accumulate.data() or ena.set()");
    enadata = ena.set(enadata);
  }
  # set = ENAset$new(
  #   enadata = enadata,
  #   dimensions = dimensions,
  #   rotation.by = rotation.by,
  #   rotation.params = rotation.params,
  #   rotation.set = rotation.set,
  #   norm.by = norm.by,
  #   node.position.method = node.position.method,
  #   endpoints.only = endpoints.only,
  #   ...
  # )$process();

  ###
  # Convert the string vector of code names to their corresponding co-occurence names
  #####
    code_columns = svector_to_ut(enadata$rotation$codes);

  ###
  # Normalize the raw data using self$function.params$norm.by,
  # which defaults to calling rENA::dont_sphere_norm_c
  #####
    line.weights = norm.by(enadata$connection.counts);
    colnames(line.weights) = code_columns;

    enadata$line.weights = cbind(enadata$meta.data, line.weights)
    class(enadata$line.weights) = c("line.weights", class(enadata$line.weights))
  #####

  ###
  # Center the normed data
  ###
  enadata$model$points.for.projection = center_data_c(line.weights);
  colnames(enadata$model$points.for.projection) = code_columns;

  enadata$model$points.for.projection = cbind(enadata$meta.data, enadata$model$points.for.projection)
  ###

  ###
  # Generate and Assign the rotation set
  ###
  if(!is.null(rotation.by) && is.null(rotation.set)) {
    rotation = do.call(rotation.by, list(enadata, rotation.params));
    enadata$rotation.matrix = rotation$rotation;
    enadata$rotation$nodes = rotation$node.positions;
    enadata$rotation$eigenvalues = rotation$eigenvalues;
  } else if (!is.null(rotation.set)) {
    if(is(rotation.set, "ENARotationSet")) {
      print("Using custom rotation.set.")

      enadata$rotation.matrix = rotation.set$rotation;
      enadata$rotation$nodes = rotation.set$node.positions;
      enadata$rotation$eigenvalues = rotation.set$eigenvalues
    } else {
      stop("Supplied rotation.set is not an instance of ENARotationSet")
    }
  } else {
    stop("Unable to find or create a rotation set")
  }
  ###

  ###
  # Generated the rotated points
  #####
    points = as.matrix(enadata$model$points.for.projection[,!colnames(enadata$model$points.for.projection) %in% colnames(enadata$meta.data), with=F]) %*% enadata$rotation.matrix;
    enadata$points = cbind(enadata$meta.data, points)
    class(enadata$points) = c("ena.points", class(enadata$points))

  #####

  ###
  # Calculate node positions
  #  - The supplied methoed is responsible is expected to return a list
  #    with two keys, "node.positions" and "centroids"
  ###
  if(!is.null(rotation) && is.null(rotation.set)) {
    positions = node.position.method(enadata);
    if(all(names(positions) %in% c("node.positions","centroids"))) {
      enadata$rotation$nodes = positions$node.positions
      enadata$model$centroids = positions$centroids
    } else {
      print("The node position method didn't return back the expected objects:")
      print("    Expected: c('node.positions','centroids')");
      print(paste("    Received: ",names(positions),sep=""));
    }
  } else if (!is.null(rotation.set)) {
    self$node.positions = rotation.set$nodes
  } else {
    stop("Unable to determine the node positions either by calculating
                them using `node.position.method` or using a supplied
                `rotation.set`");
  }
  ###

  ###
  # Variance
  ###
  variance.of.rotated.data = var(points)
  diagonal.of.variance.of.rotated.data = as.vector(diag(variance.of.rotated.data))
  enadata$model$variance = diagonal.of.variance.of.rotated.data/sum(diagonal.of.variance.of.rotated.data)


  # set$function.call = sys.call();

  # set = ena.set(set)

  enadata$model$plots = list();
  class(enadata$model$plots) = c("ena.plots", class(enadata$model$plots))

  return(enadata)
}
