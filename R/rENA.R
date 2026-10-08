#' @title rENA creates ENA sets
#' @description rENA is used to create and visualize network models of discourse and other phenomena from coded data using Epistemic Network Analysis (ENA). A more complete description of the methods will be provided with the next release. See also XXXXX
#' @name rENA
#' @importFrom grDevices col2rgb
#' @importFrom grDevices hsv
#' @importFrom grDevices rgb2hsv
#' @importFrom methods is
#' @import stats
#' @import data.table
#' @import utils
#' @import tma
#' @importFrom libqe normalize_networks scale_networks center_points
#' @importFrom libqe code_connections connection_names
#' @importFrom libqe connection_indices accumulate_stanza
#' @importFrom libqe row_connections rolling_window_sum
#' @importFrom libqe mean_ci outlier_ci group_stats
#' @importFrom Rcpp sourceCpp
#' @useDynLib rENA, .registration = TRUE
NULL

# @title Default rENA constants
# @description Default rENA constants
opts <- list (
  UNIT_NAMES = "ena.unit.names",
  TRAJ_TYPES = c("AccumulatedTrajectory", "SeparateTrajectory")
)

# @title Default colors used for plotting.
# @description Default colors for plotting
default.colors <- c(I("blue"), I("red"))
