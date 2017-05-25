##
#' @title Generate ENA Set
#'
#' @description Generate an ENA set from a given ENA data object.
#'
#' @details [TBD]
#'
#' @export
#'
#' @param enaData \code{\link{ENAdata}} that will be used to generate an ENA set
#' @param dims Number of dimensions in the set
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
