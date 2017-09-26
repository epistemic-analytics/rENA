#' @title rENA creates ENA sets
#' @description rENA is used to generate ENA sets
#' @name rENA
#' @importFrom Rcpp sourceCpp
#' @importFrom grDevices col2rgb
#' @importFrom grDevices hsv
#' @importFrom grDevices rgb2hsv
#' @importFrom methods is
#' @import stats
#' @import data.table
#' @import foreach
# @import plotly
#' @import utils
#' @import doParallel
#' @import parallel
#' @import RcppRoll
# @import scales
# @import
# @import igraph
#' @useDynLib rENA
NULL

# @title Default rENA constants
# @description Default rENA constants
opts = list (
  UNIT_NAMES = "ena.unit.names",
  TRAJ_TYPES = c("accumulated","non-accumulated")
)

# @title Default colors used for plotting.
# @description Default colors for plotting
default.colors = c(I("blue"), I("red"))

# UNIT_NAMES = "ena.unit.names"
# TRAJ_TYPES = c("accumulated","non-accumulated")
