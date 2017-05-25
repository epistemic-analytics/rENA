# rENA creates ENA sets
#
#' @importFrom Rcpp sourceCpp
#' @importFrom methods is
#' @import stats
#' @import data.table
#' @import foreach
#' @import plotly
#' @import utils
#' @useDynLib rENA, .registration = TRUE
# @name rENA

#' @export
opts = list (
  UNIT_NAMES = "ena.unit.names",
  TRAJ_TYPES = c("accumulated","non-accumulated")
)

# UNIT_NAMES = "ena.unit.names"
# TRAJ_TYPES = c("accumulated","non-accumulated")
