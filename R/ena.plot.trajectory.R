#####
#' @title Plot of ENA trajectories
#'
#' @description Function used to plot trajectories
#'
#' @export
#'
#' @param enaplot \code{\link{ENAplot}} object to use for plotting
#' @param points dataframe of matrix - first two column are X and Y coordinates, each row is a point in a trajectory
#' @param by vector used to subset points into individual trajectories, length nrow(points)
#' @param names character vector - labels for each trajectory of points, length length(unique(by))
#' @param labels character vector - point labels, length nrow(points)
#' @param labels.show A character choice: Always, Hover, Both.  Default: Both
#' @param colors A character vector, that determines marker color, default NULL results in
#' alternating random colors. If single color is supplied, it will be used for all
#' trajectories, otherwise the length of the supplied color vector should be equal
#' to the length of the supplied names (i.e a color for each trajectory being plotted)
#' @param shape A character which determines the shape of markers, choices: square, triangle, diamond, circle, default: circle
#' @param label.offset A numeric vector of an x and y value to offset labels from the coordinates of the points
#' @param label.font.size An integer which determines the font size for labels, default: enaplot$font.size
#' @param label.font.color A character which determines the color of label font, default: enaplot$font.color
#' @param label.font.family A character which determines font type, choices: Arial, Courier New, Times New Roman, default: enaplot$font.family
#' @param default.hidden A logical indicating if the trajectories should start hidden (click on the legend to show them) Default: FALSE
#' @param smooth Character choice: "none" (connect discrete points) or "poly" (fit orthogonal polynomial curve with LOOCV-2D). Default: "none"
#' @param poly.degree Fixed integer polynomial degree (default NULL = auto-select via LOOCV-2D / AIC)
#' @param poly.max.degree Maximum polynomial degree to search when auto-selecting (default: 3)
#' @param poly.criterion Criterion for polynomial degree selection: "loocv" or "aic"
#' @param poly.n.eval Number of evaluation points along the curve (default: 200)
#' @param show.points Logical: whether to display original discrete points when smooth = "poly" (default: TRUE)
#' @param show.curve Logical: whether to display smooth polynomial curve when smooth = "poly" (default: TRUE)
#'
#' @seealso \code{\link{ena.plot}}
#'
#' @examples
#' data(RS.data)
#'
#' codeNames = c('Data','Technical.Constraints','Performance.Parameters',
#'   'Client.and.Consultant.Requests','Design.Reasoning','Collaboration');
#'
#' accum = ena.accumulate.data(
#'   units = RS.data[,c("UserName","Condition")],
#'   conversation = RS.data[,c("GroupName","ActivityNumber")],
#'   metadata = RS.data[,c("CONFIDENCE.Change","CONFIDENCE.Pre","CONFIDENCE.Post","C.Change")],
#'   codes = RS.data[,codeNames],
#'   window.size.back = 4,
#'   model = "A"
#' );
#'
#' set = ena.make.set(accum);
#'
#' ### get mean network plots
#' first.game.lineweights = as.matrix(set$line.weights$Condition$FirstGame)
#' first.game.mean = colMeans(first.game.lineweights)
#'
#' second.game.lineweights = as.matrix(set$line.weights$Condition$SecondGame)
#' second.game.mean = colMeans(second.game.lineweights)
#'
#' subtracted.network = first.game.mean - second.game.mean
#'
#' # Plot dimension 1 against ActivityNumber metadata
#' dim.by.activity = cbind(
#'     as.matrix(set$points)[,1],
#'     set$trajectories$ActivityNumber * .8/14-.4  #scale down to dimension 1
#' )
#'
#' plot = ena.plot(set)
#' plot = ena.plot.network(plot, network = subtracted.network, legend.name="Network")
#' plot = ena.plot.trajectory(
#'   plot,
#'   points = dim.by.activity,
#'   names = unique(set$model$unit.label),
#'   by = set$trajectories$ENA_UNIT
#' );
#' print(plot)
#'
#' @return The \code{\link{ENAplot}} provided to the function, with its plot updated to include the trajectories
#' #####
ena.plot.trajectory = function(
  enaplot,
  points,
  by = NULL,
  labels = NULL,
  labels.show = c("Always","Hover","Both"),
  names = NULL,
  label.offset = NULL,
  label.font.size = enaplot$get("font.size"),
  label.font.color = enaplot$get("font.color"),
  label.font.family = c("Arial", "Courier New", "Times New Roman"),
  shape = c("circle", "square", "triangle-up", "diamond"),
  colors = NULL,
  default.hidden = FALSE,
  smooth = c("none", "poly"),
  poly.degree = NULL,
  poly.max.degree = 3L,
  poly.criterion = c("loocv", "aic"),
  poly.n.eval = 200L,
  show.points = TRUE,
  show.curve = TRUE
) {
  if (.qe_backend(enaplot)) {
    .qe_no_trajectories("ena.plot.trajectory")
    return(enaplot)
  }

  if(!is.character(label.font.family)) {
    label.font.size = enaplot$get("font.family");
  }
  labels.show <- match.arg(labels.show);
  shape <- match.arg(shape);
  smooth <- match.arg(smooth);
  poly.criterion <- match.arg(poly.criterion);

  if(is.null(by)) {
    by <- list(all = rep(TRUE, nrow(points)));
  }
  if (is.character(by) && length(by) == 1L && by %in% names(points)) {
    by <- points[[by]]
  }

  if (is(points, "ena.matrix") || any(find_meta_cols(points))) {
    clean_points <- remove_meta_data(points)
  } else {
    clean_points <- points
  }

  if(length(colors) == 1 && !is.null(names))
    colors <- rep(colors, length(names))

  mode <- "lines+markers+text";
  hoverinfo <- "x+y";
  tbl <- data.table::as.data.table(clean_points);
  if (!is.null(labels)) {
    if (labels.show %in% c("Always","Both"))
      mode <- paste0(mode,"+text");
    if (labels.show %in% c("Hover","Both"))
      hoverinfo <- paste0(hoverinfo,"+text");

    tbl[, labels := labels]
  }

  if(!is.null(by)) {
    if(is.character(by) && length(by) == nrow(tbl))
        by <- as.factor(by)

    dfdt_trajs <- tbl[,{ data.table::data.table(lines = list(.SD))  }, by = by]
  } else {
    dfdt_trajs <- tbl[,{ data.table::data.table(lines = list(.SD))  }]
  }

  valid_label_offsets = c("top left","top center","top right","middle left",
              "middle center","middle right","bottom left","bottom center",
              "bottom right")
  if(!all(label.offset %in% valid_label_offsets))
    stop(sprintf( "Unrecognized label.offsets: %s",
      paste(unique(label.offset[!(label.offset %in% valid_label_offsets)]),
      collapse = ", ") ))

  if(length(label.offset) == 1)
    label.offset = rep(label.offset, nrow(dfdt_trajs))

  if (!is.null(colors) &&
      length(colors) > 1 && !is.null(names) && length(colors) != length(names)
  ) {
    stop("Length of the colors must be 1 or the same length as by")
  }

  for (x in 1:nrow(dfdt_trajs)) {
    d <- as.data.frame(dfdt_trajs[x,]$lines[[1]])
    d.names <- colnames(d)
    traj_name <- if (!is.null(names) && length(names) >= x) names[x] else paste0("Trajectory ", x)
    traj_color <- if(!is.null(colors) && length(colors) >= x) colors[x] else NULL

    if (smooth == "poly" && nrow(d) >= 2L && ncol(d) >= 2L) {
      curve_fit <- .fit_etm_poly_curve(
        points = d[, 1:2, drop = FALSE],
        degree = poly.degree,
        max_degree = poly.max.degree,
        criterion = poly.criterion
      )

      # Smooth curve evaluation
      if (isTRUE(show.curve)) {
        curve_df <- .eval_etm_poly_curve(curve_fit, poly.n.eval)

        enaplot$plot = plotly::add_trace(
          enaplot$plot,
          data = curve_df,
          x = ~x,
          y = ~y,
          name = paste0(traj_name, " (fit deg ", curve_fit$degree, ")"),
          mode = "lines",
          hoverinfo = "none",
          showlegend = !isTRUE(show.points),
          line = list (
            color = traj_color,
            width = 2.5
          ),
          visible = ifelse(default.hidden, "legendonly", TRUE)
        )
      }

      # Original discrete points
      if (isTRUE(show.points)) {
        pts_mode <- if (!is.null(labels) && labels.show %in% c("Always", "Both")) "markers+text" else "markers"
        enaplot$plot = plotly::add_trace(
          enaplot$plot,
          data = d,
          x = as.formula(paste0("~", d.names[1])),
          y = as.formula(paste0("~", d.names[2])),
          name = traj_name,
          mode = pts_mode,
          text = dfdt_trajs[x,]$lines[[1]]$labels,
          textposition = label.offset[x],
          hoverinfo = hoverinfo,
          showlegend = TRUE,
          marker = list (
            symbol = shape,
            color = traj_color,
            size = 6
          ),
          textfont = list (
            family = label.font.family,
            size = label.font.size,
            color = label.font.color
          ),
          visible = ifelse(default.hidden, "legendonly", TRUE)
        )
      }
    } else {
      # Standard piecewise linear trajectory
      enaplot$plot = plotly::add_trace(
        enaplot$plot,
        data = d,
        x = as.formula(paste0("~", d.names[1])),
        y = as.formula(paste0("~", d.names[2])),
        name = traj_name,
        mode = mode,
        text = dfdt_trajs[x,]$lines[[1]]$labels,
        textposition = label.offset[x],
        hoverinfo = hoverinfo,
        showlegend = TRUE,
        line = list (
          color = traj_color
        ),
        marker = list (
          symbol = shape,
          color = traj_color
        ),
        textfont = list (
          family = label.font.family,
          size = label.font.size,
          color = label.font.color
        ),
        visible = ifelse(default.hidden, "legendonly", TRUE)
      );
    }
  }

  enaplot$plotted$trajectories[[
    length(enaplot$plotted$trajectories) + 1
  ]] <- dfdt_trajs

  return(enaplot);
}
