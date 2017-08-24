##
#' @title Plot of ENA set groups
#'
#' @description Generate a plot of a given groups for an ENA plot.
#'
#' @details [TBD]
#'
#' @export
#'
#' @param enaplot \code{\link{ENAplot}} used to generate the plot
#' @param plot.title Title of the plot
#' @param plot.mode [TBD]
#' @param plot.color Color of the plot

#' @param multiplier Size multiplier for the plot

#' @param unit.colors Color of units

#' @param unit.size change size of unit label
#' @param unit.size.multiplier Change size multiplier of unit labels
#' @param show.confidence.interval Show confidence intervals of a unit
#' @param group [TBD]
#' @param method [TBD]
#' @param group.labels [TBD]
#' @param group.labels.colors [TBD]
#' @param group.size [TBD]
#' @param ... Additional parameters addressed in inner function
#'
#' @keywords ENA, plot, set
#'
#' @seealso \code{\link{ena.make.set}}, \code{ena.update.set}
#'
#' @examples
#' \dontrun{
#' # Given an ENA plot
#' ena.plot.set(\code{\link{ENAplot}})
#'
#' }
#' @return Plot of groups of \code{\link{ENAplot}}
##
ena.plot.group <- function(
  enaplot,

  points = NULL,

  label = NULL,

  color = "black",
  shape = c("square", "triangle", "diamond", "circle"),

  show.confidence.interval = T,
  show.outlier.interval = F,

  label.font.size = enaplot$font.size,
  label.font.color = enaplot$font.color,
  label.font.family = enaplot$font.family,

  ###OLD - to be removed
  group = NULL,
  group.values = as.character(t(unique(data[,c(group),with=F]))),

  ...
) {

  shape = match.arg(shape);

  size = 5;

  ###maybe not needed
  units = unique(enaplot$enaset$enadata$get("units"));
  trajectory.by = enaplot$enaset$enadata$get("trajectory.by");
  ###

  ### is there a purpose for this?
  data = enaplot$enaset$get.data("rotated",with.meta=T);

  if(is.null(points)) points = enaplot$enaset$points.rotated;
  #dfDT = data[ENA_UNIT %in% units];

  ### save raw points for later calculations of confidence/outlier intervals
  points.raw = points;


  ### TRAJECTORY PLOT
  if(!is.null(trajectory.by)) {
    ### FOR TESTING
    print("GROUP MEAN TRAJECTORY");

    unit.colors = sapply(1:nrow(data), function(x) {
      default.colors[which(group.values == unlist(data[x,c(group),with=F]))]
    })

    dfDT.groups = dfDT[,lapply(.SD,get(method)),by=group,.SDcols=c("V1","V2")];
    dfDT.groups$ENA_UNIT = dfDT.groups$name = dfDT.groups[,c(group),with=F]
    dfDT = data.table::rbindlist(list(dfDT,dfDT.groups), fill=T)

    unit.colors = c(unit.colors, default.colors[1:length(group.values)]);

    dfDT.trajs = dfDT[,{ data.table::data.table(lines = list(.SD))  } ,by=ENA_UNIT]

    for(x in 1:nrow(dfDT.trajs)) {
      toPlot = unique(colnames(dfDT.trajs[x][[2]][[1]]))
      enaplot$plot %<>% plotly::add_trace(
        data = dfDT.trajs[x][[2]][[1]][,toPlot,with=FALSE],
        x = ~V1, y = ~V2,
        name = dfDT.trajs[x][[1]],
        mode = "lines+markers",
        text = dfDT.trajs[x][[2]][[1]]$TRAJ_UNIT,
        hoverinfo = "text+x+y"
      )
    }
    enaplot$plot %<>% plotly::hide_legend();

    return(enaplot);
  } else {     #### NON-TRAJECTORY PLOT
    print(points)
    ### if group more than one row, combine to mean
    if(nrow(points) > 1) {
      points = colMeans(points);
    }
    print(points)

    #calculate CI's
    if(show.confidence.interval == T) {

      conf.ints = points.raw[, { cis = t.test(.SD)$conf.int; data.table::data.table(ci.x=cis[1], ci.y=cis[2]) },,.SDcols=c("V1","V2")]
      dfDT.points = merge(points, conf.ints);
      dfDT.points[, c("ci.x1", "ci.x2", "ci.y1", "ci.y2") := .(V1 - ci.x, V1 + ci.x, V2 - ci.y, V2 + ci.y)]

      lines = apply(dfDT.points,1,function(x) {
        list(
          "type" = "square",
          "line" = list(
            width = 1,
            color = default.colors[which(group.values == x[[group]])],
            dash="dash"
          ),
          "xref" = "x",
          "yref" = "y",
          "x0" = x[['ci.x1']],
          "x1" = x[['ci.x2']],
          "y0" = x[['ci.y1']],
          "y1" = x[['ci.y2']]
        );
      });
    }
    if(show.outlier.interval == T) {
      ###calculate outlier intervals

    }

    group.layout = data.frame(dfDT);

    enaplot$plot %<>% plotly::add_trace(
      data = group.layout,
      type="scatter",
      x = ~V1, y = ~V2,
      mode="markers",
      marker = list(
        symbol =  shape,  #c(rep("circle",nrow(data)),rep("square", ifelse(!is.null(dfDT.groups), nrow(dfDT.groups), 0))),
        color = color,
        #size = c(rep(unit.size * unit.size.multiplier, nrow(data)), rep(group.size, ifelse(!is.null(dfDT.groups),nrow(dfDT.groups), 0)))
        size = size
      ),
      showlegend = F,
      #text = ~name,
      hoverinfo = "text+x+y"
    )

    ### plot CI's
    enaplot$plot %<>% plotly::layout(
      shapes = lines
    )

  }

  return(enaplot);
}
