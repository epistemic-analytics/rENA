# rENA creates ENA sets
#
#' @useDynLib rENA
#' @importFrom Rcpp sourceCpp
#' @import stats
#' @import data.table
#' @import foreach
#' @import plotly
#' @import readr
# @name rENA

#' @export
opts = list (
  UNIT_NAMES = "ena.unit.names",
  TRAJ_TYPES = c("accumulated","non-accumulated")
)

# UNIT_NAMES = "ena.unit.names"
# TRAJ_TYPES = c("accumulated","non-accumulated")
