##
#' @title Generate ENA Set
#'
#' @description Generates an ENA set from a given ENA data object.
#'
#' @details This function generates an ENAset object from an ENAdata object. Using the provided accumulation and additional parameters this function processes the accumulated data to create an ENAset which contains information on the locations of the the points and nodes, as well as line weights for node connections.
#'
#' @export
#'
#' @param enadata \code{\link{ENAdata}} that will be used to generate an ENA set
#' @param dimensions The number of dimensions to be in the set
#' @param norm.by A function to be used to norm the data, default: sphere_norm_c()
#' @param rotation.by A function to be used to rotate the data, default: ena.svd()
#' @param rotation.params A character vector containing the parameters for the rotation function
#' @param rotation.set An ENARotationSet object to use for rotation
#' @param endpoints.only A logical variable which determines whether to only show endpoints for trajectory models
#' @param node.position.method A function to be used to determine node positions, default: lws.position.es()
#' @param ... additional parameters addressed in inner function
#'
#' @keywords ENA, generate, set
#'
#' @seealso \code{\link{ena.accumulate.data}}, \code{\link{ENAset}}
#'
#' @examples
#' \dontrun{
#' #Given an \code{\link{ENAdata}}
#' ena.make.set(\code{\link{ENAdata}})
#' }
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
  node.position.method = lws.positions.es,
  ...

  # private properties of ENAset
  #dims=2,    #usein in egr.pos/optimization --- to be determined
  #samples=3,   #usein in egr.pos -- make local to egr
  #inPar=F,    #used in egr.pos-- make local to egr

  ####
  #sphere.norm=dont_sphere_norm_c,   #now called norm.by
  #center.data=center_data_c,     ### made local in run - always center_data_c
  #optim.method=do_optimization,  # - now local to ENAset, used by egr.position
  #position.method=egr.positions, #-> node.position.method

  ### what to do with these 2?
  #check.unique.positions=F,
  # set.seed = F,

  ### leaving for now so testing can occur w/o errors
  # rotate.means = F,
  # rotate.means.by = NULL,
  #

  ### NO LONGER BEING INCLUDED
  #output = c("class","json"),
  #output.fields = NULL,

) {
  set = ENAset$new(
    enadata = enadata,

    dimensions = dimensions,
    rotation.by = rotation.by,
    rotation.params = rotation.params,
    rotation.set = rotation.set,

    node.position.method = node.position.method,

    endpoints.only = endpoints.only,

    #### TO BE REMOVED
    # set.seed = set.seed,
    # rotate.means = rotate.means,
    # rotate.means.by = rotate.means.by,
    ####

    ...

  )$process();

  #output = match.arg(output);

  # if(output == "json") {
  #   output.class = get(class(set))
  #
  #   if(is.null(output.fields)) {
  #     output.fields = names(output.class$public_fields)
  #   }
  #
  #   r6.to.json(set, o.class = output.class, o.fields = output.fields)
  # }
  # else
  return(set)
}
