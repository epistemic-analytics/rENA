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
#' @param show.confidence.intervals Show confidence intervals of a unit
#' @param group [TBD]
#' @param group_by [TBD]
#' @param group.labels [TBD]
#' @param group.labels.positions [TBD]
#' @param group.labels.colors [TBD]
#' @param group.size [TBD]
#' @param group.size.multiplier [TBD]

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
ena.plot.groups <- function(
  enaplot,

  plot.title = "ENA Plot",
  plot.mode = "units+network",
  plot.color = I("black"),

  multiplier = 5,

  units = unique(enaplot$enaset$get("enaData")$get("units")),

  unit.colors = rep(plot.color, nrow(enaset$points.rotated)),

  unit.size = 1,
  unit.size.multiplier = multiplier,

  trajectory.by = NULL,

  show.confidence.intervals = T,

  group = NULL,
  group.values = as.character(t(unique(data[,c(group),with=F]))),
  group_by = c("mean","sum"),
  group.labels = names(groups),
  group.labels.positions = "top right",
  group.labels.colors = rep(plot.color, length(group)),
  group.size = unit.size,
  group.size.multiplier = unit.size.multiplier,

  ...
) {



  #group_by <- match.arg(group_by);
  data = enaplot$enaset$get.data("rotated",with.meta=T);

  dfDT = data[ENA_UNIT %in% units];

  df.names = dfDT$ENA_UNIT;
  if(is.null(df.names)) {
    df.names = as.character(1:nrow(data))
    rownames(data) = df.names;
  }
  dfDT[,name:=ENA_UNIT] # Create a name column

  show.modes = unlist(strsplit(plot.mode,split="\\+"))
  show.units = "units" %in% show.modes;
  show.networks = "network" %in% show.modes;

  if(!is.null(trajectory.by)) {
    ### FOR TESTING
    print("GROUP MEAN TRAJECTORIES");

    unit.colors = sapply(1:nrow(data), function(x) {
      default.colors[which(group.values == unlist(data[x,c(group),with=F]))]
    })
    dfDT.groups = dfDT[,lapply(.SD,get(group_by)),by=group,.SDcols=c("V1","V2")];
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
  }

  if(!is.null(group)) {
    unit.colors = sapply(1:nrow(data), function(x) {
      default.colors[which(group.values == unlist(data[x,c(group),with=F]))]
    })
    dfDT.groups = dfDT[,lapply(.SD,get(group_by)),by=group,.SDcols=c("V1","V2")];
    dfDT.groups$ENA_UNIT = dfDT.groups$name = dfDT.groups[,c(group),with=F]
    dfDT = data.table::rbindlist(list(dfDT,dfDT.groups), fill=T)

    unit.colors = c(unit.colors, default.colors[1:length(group.values)]);

    #calculate CI's
    if(show.confidence.intervals == T) {
      message("Confidence intervals on means not yet implemented.")
      conf.ints = data[, { cis = t.test(.SD)$conf.int; data.table::data.table(ci.x=cis[1], ci.y=cis[2]) },by=c(group),.SDcols=c("V1","V2")]

      dfDT.groups = merge(dfDT.groups, conf.ints);
      dfDT.groups[, c("ci.x1", "ci.x2", "ci.y1", "ci.y2") := .(V1 - ci.x, V1 + ci.x, V2 - ci.y, V2 + ci.y)]

      lines = apply(dfDT.groups,1,function(x) {
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

    group.layout = data.frame(dfDT);

    ### new - modify colors of points trace, then will need to add trace
    # if("points" %in% p$traces) {
    #   print("points already plotted");
    #   enaplot$plot %<>% style(
    #     type="scatter",
    #     # x = ~V1, y = ~V2,
    #     mode="markers",
    #     marker = list(
    #       symbol = c(rep("circle",nrow(data)),rep("square", ifelse(!is.null(dfDT.groups), nrow(dfDT.groups), 0))),
    #       color = unit.colors,
    #       size = c(rep(unit.size * unit.size.multiplier, nrow(data)), rep(group.size * group.size.multiplier, ifelse(!is.null(dfDT.groups),nrow(dfDT.groups), 0)))
    #     ),
    #     showlegend = F,
    #     text = ~name,
    #     hoverinfo = "text+x+y",
    #
    #     traces = which(p$traces == "points"))
    # } else {
    #   enaplot$plot %<>% plotly::add_trace(
    #     data = group.layout,
    #     type="scatter",
    #     x = ~V1, y = ~V2,
    #     mode="markers",
    #     marker = list(
    #       symbol = c(rep("circle",nrow(data)),rep("square", ifelse(!is.null(dfDT.groups), nrow(dfDT.groups), 0))),
    #       color = unit.colors,
    #       size = c(rep(unit.size * unit.size.multiplier, nrow(data)), rep(group.size * group.size.multiplier, ifelse(!is.null(dfDT.groups),nrow(dfDT.groups), 0)))
    #     ),
    #     showlegend = F,
    #     text = ~name,
    #     hoverinfo = "text+x+y"
    #   )
    # }

    ### OLD VERSION - plot and color points and means - now used via plot.points instead of separately
    enaplot$plot %<>% plotly::add_trace(
      data = group.layout,
      type="scatter",
      x = ~V1, y = ~V2,
      mode="markers",
      marker = list(
        symbol = c(rep("circle",nrow(data)),rep("square", ifelse(!is.null(dfDT.groups), nrow(dfDT.groups), 0))),
        color = unit.colors,
        size = c(rep(unit.size * unit.size.multiplier, nrow(data)), rep(group.size * group.size.multiplier, ifelse(!is.null(dfDT.groups),nrow(dfDT.groups), 0)))
      ),
      showlegend = F,
      text = ~name,
      hoverinfo = "text+x+y"
    )

    ### plot CI's
    enaplot$plot %<>% plotly::layout(
      title = plot.title,
      shapes = lines
    )

  }

  return(enaplot);
}
