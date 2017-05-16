##
#' @title Generate ENA Set
#' @description Generate an ENA set from a givent ENA data object
#'
#'
#'
#' @export
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
  check.unique.positions=F,
  set.seed = F,
  rotate.means = F,
  rotate.means.by = NULL,
  output = c("class","json"),
  ...
) {
  set = ENAset$new(
    enaData,
    dims,
    samples,
    inPar,
    codeColumns,
    binary,
    correction,
    sphere.norm,
    center.data,
    optim.method,
    check.unique.positions,
    set.seed,
    rotate.means,
    rotate.means.by,
    ...
  )$process();

  output = match.arg(output);

  if(output == "json") r6.to.json(set)
  else set
}
