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
#' @import doParallel
#' @import parallel
#' @import tma
#' @importFrom libqe lq_sphere_norm lq_skip_sphere_norm lq_center_data
#' @importFrom libqe lq_vector_to_upper_tri lq_svector_to_upper_tri
#' @importFrom libqe lq_tri_indices lq_stanza_window
#' @importFrom libqe lq_rows_to_co_occurrences lq_rolling_window_sum
#' @importFrom libqe lq_lws_lsq_positions lq_directed_node_positions
#' @importFrom libqe lq_directed_node_positions_ground_response lq_ena_correlation
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
