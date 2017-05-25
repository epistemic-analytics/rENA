##
#' @title Plot network
#' @description Accumulate rows of data
#'
#'
#'
# @export
##
ena.plot.units = function(
  enaset,
  data = enaset$get.data("rotated",with.meta=T),
  plot = NULL,
  plot.title,

  unit.size = 1,
  unit.size.multiplier = 5,
  unit.colors = rep(I("blue"), nrow(data)),

  unit.group = NULL,
  unit.group.values = as.character(t(unique(data[,c(unit.group),with=F]))),
  unit.group_by = c("mean","sum"),
  unit.group.labels = names(unit.group),
  unit.group.labels.positions = "top right",
  unit.group.labels.colors = rep(default.colors[1], length(unit.group)),
  unit.show.confidence.intervals = T,
  unit.group.size = 1,
  unit.group.size.multiplier = 5,

  font.size = 10,
  font.color = "000000",
  font.family = "Arial"
) {
  unit.group_by <- match.arg(unit.group_by);

  dfDT = data;
  df.names = dfDT$ENA_UNIT;
  if(is.null(df.names)) {
   df.names = as.character(1:nrow(data))
   rownames(data) = df.names;
  }
  dfDT[,name:=ENA_UNIT] # Create a name column

  network.vertices.df = dfDT[,c(ncol(dfDT),1:ncol(dfDT)-1),with=F];

  dfDT.groups = NULL
  lines <- list()
  if(!is.null(unit.group)) {
    unit.colors = sapply(1:nrow(data), function(x) {
      default.colors[which(unit.group.values == unlist(data[x,c(unit.group),with=F]))]
    })
    dfDT.groups = dfDT[,lapply(.SD,get(unit.group_by)),by=unit.group,.SDcols=c("V1","V2")];
    dfDT.groups$ENA_UNIT = dfDT.groups$name = dfDT.groups[,c(unit.group),with=F]
    dfDT = data.table::rbindlist(list(dfDT,dfDT.groups), fill=T)

    unit.colors = c(unit.colors, default.colors[1:length(unit.group.values)]);

    if(unit.show.confidence.intervals == T) {
      message("Confidence intervals on means not yet implemented.")
      conf.ints = data[, { cis = t.test(.SD)$conf.int; data.table(ci.x=cis[1], ci.y=cis[2]) },by=c(unit.group),.SDcols=c("V1","V2")]

      dfDT.groups = merge(dfDT.groups, conf.ints);
      dfDT.groups[, c("ci.x1", "ci.x2", "ci.y1", "ci.y2") := .(V1 - ci.x, V1 + ci.x, V2 - ci.y, V2 + ci.y)]
      lines = apply(dfDT.groups,1,function(x) {
        list(
          "type" = "square",
          "line" = list(
            width = 1,
            color = default.colors[which(unit.group.values == x[[unit.group]])],
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
  }

  network.layout = data.frame(dfDT);
  network.font.text = list(
    family = font.family,
    size = font.size,
    color = font.color
  )

  network.graph.axis <- list(title = "", showgrid = FALSE, showticklabels = FALSE, zeroline = T);
  network.plot = plotly::plot_ly(
    network.layout,
    type="scatter",
    x = ~V1, y = ~V2,
    mode="markers",
    marker = list(
      symbol = c(rep("circle",nrow(data)),rep("square",nrow(dfDT.groups))),
      color = unit.colors,
      size = c(rep(unit.size * unit.size.multiplier, nrow(data)), rep(unit.group.size * unit.group.size.multiplier, nrow(dfDT.groups)))
    ),
    showlegend = F,
    text = dfDT$name,
    hoverinfo = "text"
  )
  network.plot.layout = plotly::layout(
    network.plot,
    title =  plot.title,
    xaxis = network.graph.axis,
    yaxis = network.graph.axis,
    shapes = lines
  )

  network.plot.layout
}
