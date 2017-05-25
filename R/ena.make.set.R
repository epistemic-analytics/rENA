##
#' @title Generate ENA Set
#'
#' @description Generate an ENA set from a givent ENA data object
#'
#' @details NEED TO ADD
#'
#' @export
#'
#' @param enaData
#' @param dims
#' @param samples
#' @param inPar
#' @param codeColumns
#' @param binary
#' @param correction
#' @param sphere.norm
#' @param center.data
#' @param optim.method
#' @param position.method
#' @param check.unique.positions
#' @param set.seed
#' @param rotate.means
#' @param rotate.means.by
#' @param output
#' @param ...
#'
#' @keywords ENA, generate, set
#'
#' @seealso \code{\link{ena.accumulate.data}}, \code{\link{ena.split.codes}}
#'
#' @examples
#' \dontrun{
#' #ADD EXAMPLES
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
