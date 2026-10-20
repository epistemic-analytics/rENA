# Post-fit node moves for display. The math is libena's
# (inst/include/libena/positions.hpp: unit_circle_nodes, node_centroids),
# shared with qe-ena, rena-wasm and ENA.jl.

#' Move nodes onto a circle along their own rays
#'
#' A post-fit display transform: in the plane of two dimensions, pushes every
#' node out along its own ray to the length of the longest node there, then
#' recomputes the centroids for the moved nodes. Nothing is refit.
#'
#' Nodes of length zero in the plane are left where they are, as are the
#' nodes' other dimensions. Unit points never change. The centroids, all
#' dimensions of them, are the model's node weights times the moved nodes:
#' each unit's line weights split between the codes they connect (half to
#' each code for unordered networks; for ordered ones, as the fit weights
#' them) and normalised to sum to 1, the weighting the fit's own centroids
#' use. So the goodness of fit (\code{\link{ena.correlations}}) reflects the
#' moved nodes.
#'
#' Works for unordered and ordered (\code{accumulate(ordered = TRUE)}) sets.
#'
#' @param set An \code{ena.set}, e.g. from \code{\link{model}} or
#'   \code{\link{ena.make.set}}.
#' @param dimension_name_1 Name of the plane's x dimension (a column of
#'   \code{set$rotation$nodes}). Defaults to the first dimension.
#' @param dimension_name_2 Name of the plane's y dimension. Defaults to the
#'   second dimension.
#'
#' @return \code{set}, with \code{set$rotation$nodes} moved on the two
#'   dimensions and \code{set$model$centroids} recomputed.
#'
#' @seealso \code{\link{move_nodes_to_unit_circle_with_equal_space}}, which
#'   also spaces the nodes equally around the circle.
#' @examples
#' data(RS.data)
#' codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
#'            "Client.and.Consultant.Requests", "Design.Reasoning",
#'            "Collaboration")
#' set <- RS.data |>
#'   accumulate(c("Condition", "UserName"), codes, c("Condition", "GroupName")) |>
#'   model()
#' circled <- move_nodes_to_unit_circle(set)
#' circled$rotation$nodes
#' @export
move_nodes_to_unit_circle <- function(
    set,
    dimension_name_1 = colnames(as.matrix(set$rotation$nodes))[1],
    dimension_name_2 = colnames(as.matrix(set$rotation$nodes))[2]
) {
  move_nodes_on_circle(set, dimension_name_1, dimension_name_2, "radial")
}

#' Move nodes onto a circle, equally spaced
#'
#' A post-fit display transform: in the plane of two dimensions, places the
#' nodes on a circle with the radius of the longest node there, keeping
#' their order around the origin and spacing them \eqn{2\pi/n} apart,
#' starting from the longest node, which stays where it is. Then recomputes
#' the centroids for the moved nodes. Nothing is refit.
#'
#' The order around the origin is: nodes with a non-negative y coordinate by
#' decreasing x, then nodes with a negative y coordinate by increasing x
#' (ties keep the codes' order). When two nodes are equally long, the first
#' stays fixed. Nodes of length zero in the plane are left where they are and
#' do not count towards \eqn{n}. The rest is as for
#' \code{\link{move_nodes_to_unit_circle}}.
#'
#' @inheritParams move_nodes_to_unit_circle
#' @inherit move_nodes_to_unit_circle return
#'
#' @seealso \code{\link{move_nodes_to_unit_circle}}, which moves each node
#'   along its own ray instead.
#' @examples
#' data(RS.data)
#' codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
#'            "Client.and.Consultant.Requests", "Design.Reasoning",
#'            "Collaboration")
#' set <- RS.data |>
#'   accumulate(c("Condition", "UserName"), codes, c("Condition", "GroupName")) |>
#'   model()
#' spaced <- move_nodes_to_unit_circle_with_equal_space(set)
#' spaced$rotation$nodes
#'
#' # Another plane, e.g. the second and third dimensions
#' dims <- colnames(as.matrix(set$rotation$nodes))
#' move_nodes_to_unit_circle_with_equal_space(set, dims[2], dims[3])
#' @export
move_nodes_to_unit_circle_with_equal_space <- function(
  set,
  dimension_name_1 = colnames(as.matrix(set$rotation$nodes))[1],
  dimension_name_2 = colnames(as.matrix(set$rotation$nodes))[2]
) {
  move_nodes_on_circle(set, dimension_name_1, dimension_name_2, "equal")
}

# Shared body: libena moves the nodes (mode "radial" or "equal") and
# recomputes the centroids; the set gets them back with its column classes.
move_nodes_on_circle <- function(set, dimension_name_1, dimension_name_2, mode) {
  nodes <- as.matrix(set$rotation$nodes)
  dimension_names <- c(dimension_name_1, dimension_name_2)
  idx <- match(dimension_names, colnames(nodes))
  if (anyNA(idx)) {
    stop("Unknown dimension(s): ",
         paste(dimension_names[is.na(idx)], collapse = ", "),
         ". Use columns of set$rotation$nodes: ",
         paste(colnames(nodes), collapse = ", "))
  }

  # Ordered sets: recompute centroids with the self-connection weight the
  # nodes were fit with. Sets fit before it was recorded used 1 (libena
  # counted self-connections once from 2026-05 until rENA 0.4.16).
  self_weight <- if (is.null(set$rotation$self.weight)) 1 else set$rotation$self.weight
  lw <- as.matrix(set$line.weights)
  key <- set$rotation$adjacency.key
  moved <- if (!is(set, "ena.ordered.set") && !is.null(key) && ncol(as.matrix(key)) == ncol(lw)) {
    # Unordered: centroids from the same key-driven weighting the fit used
    # (self-connection columns included).
    ft <- key_indices(key, key_codes(key, set$rotation$codes))
    move_nodes_to_unit_circle_by_key_c(lw, nodes, idx[1] - 1L, idx[2] - 1L, mode,
                                       ft$from, ft$to, self_weight)
  } else {
    move_nodes_to_unit_circle_c(lw, nodes, idx[1] - 1L, idx[2] - 1L, mode,
                                is(set, "ena.ordered.set"), self_weight)
  }

  set$rotation$nodes <- replace_dimension_columns(
    set$rotation$nodes, moved$nodes[, idx, drop = FALSE], dimension_names
  )
  set$model$centroids <- replace_dimension_columns(
    set$model$centroids, moved$centroids, colnames(nodes)
  )
  set
}

# A copy of the data.table x (nodes or centroids) with columns `cols` replaced
# by the columns of the matrix `values`, each keeping its attributes (class).
replace_dimension_columns <- function(x, values, cols) {
  x <- data.table::copy(x)
  for (k in seq_along(cols)) {
    value <- as.numeric(values[, k])
    attributes(value) <- attributes(x[[cols[k]]])
    data.table::set(x, j = cols[k], value = value)
  }
  x
}
