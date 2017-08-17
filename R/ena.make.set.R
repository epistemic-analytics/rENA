##
#' @title Generate ENA Set
#'
#' @description Generates an ENA set from a given ENA data object.
#'
#' @details [TBD]
#'
#' @export
#'
#' @param enadata \code{\link{ENAdata}} that will be used to generate an ENA set
#' @param dims Number of dimensions to be in the set
#' @param samples [TBD]
#' @param inPar [TBD]
#' @param codeColumns Number of columns of codes in the ENA set
#' @param binary [TBD]
#' @param correction [TBD]
#' @param sphere.norm [TBD]
#' @param center.data [TBD]
#' @param optim.method [TBD]
#' @param position.method [TBD]
#' @param check.unique.positions [TBD]
#' @param set.seed [TBD]
#' @param rotate.means [TBD]
#' @param rotate.means.by [TBD]
#' @param output [TBD]
#' @param output.fields Fields to be included in JSON output
#' @param ... additional parameters addressed in inner function
#'
#' @keywords ENA, generate, set
#'
#' @seealso \code{\link{ena.accumulate.data}}, \code{\link{ena.split.codes}}
#'
#' @examples
#' \dontrun{
#' #Given an \code{\link{ENAdata}}
#' ena.make.set(\code{\link{ENAdata}})
#' }
#'
#' @return \code{\link{ENAset}} class object
##
ena.make.set <- function(
  enadata,
  dimensions = 2,
  #NEW
  norm.by = sphere_norm_c,  #was sphere_norm
  rotation.by = NULL,
  rotation.set = NULL,
  endpoints.only = T,
  node.position.method = lws.positions.es,     #was position.method
  #end new

  # private properties of ENAset
  #dims=2,    #usein in egr.pos/optimization --- to be determined
  #samples=3,   #usein in egr.pos -- make local to egr
  #inPar=F,    #used in egr.pos-- make local to egr

  ####
  #sphere.norm=dont_sphere_norm_c,   #now called norm.by
  #center.data=center_data_c,     ### made local in run - always center_data_c
  #optim.method=do_optimization,  # - now local to ENAset, used by egr.position
  #position.method=egr.positions, #-> node.position.method

  ### what to do with these?
  check.unique.positions=F,    #remove from here for now
  set.seed = F,       #remove from here for now
  rotate.means = F,    #### replaced by rotation.by
  rotate.means.by = NULL,    #### replaced by rotation.by
  #

  output = c("class","json"),
  output.fields = NULL,
  ...
) {
  set = ENAset$new(
    enadata = enadata,

    dimensions,
    #samples = samples,
    #inPar = inPar,

    norm.by = norm.by,

    rotation.by = rotation.by,
    rotation.set = rotation.set,

    #center.data = center.data,
    #optim.method = optim.method,
    node.position.method = node.position.method,

    endpoints.only,

    #### TO BE REMOVED
    set.seed = set.seed,
    rotate.means = rotate.means,
    rotate.means.by = rotate.means.by,

    ...

  )$process();

  output = match.arg(output);

  if(output == "json") {
    output.class = get(class(set))

    if(is.null(output.fields)) {
      output.fields = names(output.class$public_fields)
    }

    r6.to.json(set, o.class = output.class, o.fields = output.fields)
  }
  else set
}
