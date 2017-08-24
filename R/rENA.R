#' @title rENA creates ENA sets
#' @description rENA is used to generate ENA sets
#' @name rENA
#' @importFrom Rcpp sourceCpp
#' @importFrom methods is
#' @import stats
#' @import data.table
#' @import foreach
# @import plotly
#' @import utils
#' @import doParallel
#' @import parallel
#' @import RcppRoll
#' @import magrittr
# @import igraph
#' @useDynLib rENA
NULL

#' @title Default rENA constants
#' @description Default rENA constants
#' @export
opts = list (
  UNIT_NAMES = "ena.unit.names",
  TRAJ_TYPES = c("accumulated","non-accumulated")
)

#' @title Default colors used for plotting.
#' @description Default colors for plotting
#' @export
default.colors = c(I("blue"), I("red"))

# UNIT_NAMES = "ena.unit.names"
# TRAJ_TYPES = c("accumulated","non-accumulated")
