##
#' @title Generate ENA Set
#'
#' @description Generate an ENA set from a givent ENA data object
#'
#' @details NEED TO ADD
#'
#' @export
#'
#' @param accumulated.data \code{\link{ENAData}} from ena.accumulate.data(), parameters passed to ena.accumulate.data
#' @param dimensions Number of dimensions desired
#' @param norm.by NEEDS DETAILS
#' @param rotations.by Functions to use per dimension
#' @param rotate.groups NEEDS DETAILS
#' @param rotate.groups.using NEEDS DETAILS
#' @param mask.connections NEEDS DETAILS
#' @param rotation.set \code{\link{ENARotationSet}} from a previously created ENAset
#' @param use.endpoints NEEDS DETAILS
#' @param optim.method NEEDS DETAILS
#'
#' @keywords ENA, generate, set
#'
#' @seealso \code{\link{ena.accumulate.data()}}, \code{\link{ena.split.codes()}}
#'
#' @examples
#' #ADD EXAMPLES
#'
#' @return \code{\link{ENAset}} class object
##
ena.make.set <- function(
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
  position.method=egr.positions,
  check.unique.positions=F,
  set.seed = F,
  rotate.means = F,
  rotate.means.by = NULL,
  output = c("class","json"),
  ...
) {
  set = ENAset$new(
    enaData = enaData,
    dims = dims,
    samples = samples,
    inPar = inPar,
    codeColumns = codeColumns,
    binary = binary,
    correction = correction,
    sphere.norm = sphere.norm,
    center.data = center.data,
    optim.method = optim.method,
    position.method = position.method,
    check.unique.positions = check.unique.positions,
    set.seed = set.seed,
    rotate.means = rotate.means,
    rotate.means.by = rotate.means.by,
    ...
  )$process();

  output = match.arg(output);

  if(output == "json") r6.to.json(set)
  else set
}
