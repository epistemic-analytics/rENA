##
#' @title Accumulate and Generate
#'
#' @description Accumulate and Generate
#'
#' @details [TBD]
#'
#' @param data.params [TBD]
#' @param set.params [TBD]
#'
#' @export
#'
#' @return list containing the accumulation and set
##
ena.generate <- function(file, window.size.back, units.by, conversations.by, code) {
  accum = ena.accumulate.data.file(
    file = file,
    window.size.back = window.size.back,
    units.by = units.by,
    conversations.by = conversations.by,
    code = code
  )
  set = ena.make.set(
    enadata = accum
  )

  return( set );
}
