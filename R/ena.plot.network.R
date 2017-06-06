
ena.plot.network = function(
  enaset = NULL, plot = NULL,
  units.by = enaset$get('enaData')$get('units.by'),
  group.by = enaset$get('enaData')$get('conversations.by'), #"Condition",

  selection.one.color = "#5399c7",
  selection.one.name = NULL,
  selection.one.title = NULL,

  selection.two.color = "#FF0000",
  selection.two.name = NULL,
  selection.two.title = NULL,

  weight.multiplier = 20,
  font.size = 10,
  font.color = "000000",
  font.family = "Arial",

  node.weight.multiplier = weight.multiplier,
  node.color = "#464646",
  node.font.size = font.size,
  node.font.family = font.family,
  node.font.color = font.color,

  edge.weight.multiplier = weight.multiplier,
  edge.font.size = font.size,
  edge.font.color = font.color,
  edge.font.family = font.family,
  edge.hide = NULL,

  network.edge.threshold = 0,
  network.show.all.codes = F
) {
  df = data.frame(enaset$data$normed, attr(enaset$data$normed, rENA::opts$UNIT_NAMES));
  dfDT= data.table::as.data.table(df);
  dfDT$handle = merge_columns_c(dfDT,units.by, sep="."); #rownames(df);

  units.to.plot = c(selection.one.name, selection.two.name);

  sdcols=colnames(dfDT)[sapply(dfDT, is.numeric)];
  minDT = dfDT[handle %in% units.to.plot, lapply(.SD,sum,na.rm=T), by=units.by, .SDcols=sdcols];

  minDT$ENA_UNIT = merge.columns(x = minDT, from.cols = units.by);
  minDT = minDT[match(ENA_UNIT, units.to.plot),];

  minDTc =minDT[,apply(.SD,2,make.network.node, types=c(selection.one.color, selection.two.color)),.SDcols=sdcols, with = T];
  minDTsizes = minDTc[1,!is.na(minDTc[2,]), with=F];
  minDTcolors = minDTc[2,!is.na(minDTc[2,]), with=F];
  minDTsizes = minDTsizes[,which(!names(minDTcolors) %in% group.by),with=F];
  minDTcolors = minDTcolors[,which(!names(minDTcolors) %in% group.by),with=F];
  minDTnodes = minDTc[,!is.na(minDTc[2,]), with=F]
  minDTnodes = minDTnodes[,which(!names(minDTcolors) %in% group.by),with=F]
  minDTnodes = minDTnodes[,{ cols=strsplit(colnames(.SD), "...", fixed=T); m=as.matrix(.SD[,,with=F]); lapply(1:length(cols),function(x){ c(m[1,x],m[2,x],cols[[x]]) }); },];

  minDTnodes_trans = t(minDTnodes);
  minDTnodes_trans = minDTnodes_trans[,c(3:4,1:2)];

  network.edges = minDTnodes_trans; #as.data.frame(get.edgelist(network.graph));
  network.edges.table = data.table::as.data.table(network.edges);

  ## Remove edges below threshold
  network.edges.table = network.edges.table[V3 > network.edge.threshold]

  ## Remove nodes without connections

  ## Remove edges explicitly hidden
  if(!is.null(edge.hide)) {
    network.edges.table = network.edges.table[!network.edges.table$V2 %in% edge.hide|!network.edges.table$V2 %in% edge.hide,]
  }
  network.edges.length = nrow(network.edges.table);

  df.names = rownames(enaset$nodes$positions$scaled);
  if(is.null(df.names)) {
   df.names = as.character(1:nrow(enaset$nodes$positions$scaled))
   rownames(enaset$nodes$positions$scaled) = df.names;
  }
  network.vertices.df = data.frame(
    name = df.names, ## New LWS method needs to assign names/attr
    enaset$nodes$positions$scaled
  );
  network.graph = igraph::graph_from_data_frame(
    minDTnodes_trans,
    directed = F,
    vertices = network.vertices.df
  )
  network.layout = enaset$nodes$positions$scaled;
  network.vertices = igraph::V(network.graph);
  network.vertices.length = length(network.vertices);
  network.font.text = list(
    family = node.font.family,
    size = node.font.size,
    color = node.font.color
  )

  network.nodes.x = network.layout[,1];
  network.nodes.y = network.layout[,2];

  network.edges.shapes = list();
  for (i in 1:network.edges.length) {
    # browser()
    v0 <- unlist(network.edges.table[i,][[1]]); #network.edges.table[i,][[1]];
    v1 <- unlist(network.edges.table[i,][[2]]); #network.edges.table[i,][[2]];
    edge_shape = list(
      type = "line",
      line = list(
        color=unlist(network.edges.table[i,][[4]]), #network.edges.table[i,][[4]],
        width=unlist(network.edges.table[i,][[3]]) * edge.weight.multiplier #network.edges.table[i,][[3]]
      ),
      x0 = network.vertices.df[v0,]$X1, #network.nodes.x[0],
      y0 = network.vertices.df[v0,]$X2, #network.nodes.y[0],
      x1 = network.vertices.df[v1,]$X1, #network.nodes.x[1],
      y1 = network.vertices.df[v1,]$X2 #network.nodes.y[1]
    );
    network.edges.shapes[[i]] = edge_shape
  }

  network.graph.axis <- list(title = "", showgrid = FALSE, showticklabels = FALSE, zeroline = T);
  node.sizes = sapply(rownames(network.layout), function(x) { network.edges.table[V1==x|V2==x, sum(unlist(V3)),] }) * node.weight.multiplier

  if(!network.show.all.codes) {
    node.sizes = node.sizes[which(data.frame(node.sizes)$node.sizes != 0)]
    network.layout = network.layout[rownames(network.layout) %in% names(node.sizes),]
  }
  network.plot = plotly::plot_ly(
    data.frame(network.layout),
    type="scatter",
    x = ~X1,
    y = ~X2,
    mode="markers",
    marker = list(
      color = I(node.color),
      size = as.numeric(node.sizes)
    ),
    showlegend = F,
    text = rownames(network.layout)
  );
  network.plot = plotly::add_annotations(
    network.plot,
    textfont = network.font.text,
    xref = "x",
    yref = "y",
    xanchor = "center",
    standoff = 30,
    #clicktoshow = "onout",
    #captureevents = T,
    visible = F,
    #ax = 20, #sample(200, nrow(network.layout), replace=T),
    #ay = -90,
    showarrow = F
    #textposition = "top right"
  );

  selection.one.title = stringr::str_c("<b style=\"color:",selection.one.color,"\">",selection.one.name,"</b>");

  if(!is.null(selection.two.name)) {
    selection.two.title = stringr::str_c("<b style=\"color:",selection.two.color,"\">",selection.two.name,"</b>");
  }

  network.plot.layout = plotly::layout(
    network.plot,
    title =  stringr::str_c(selection.one.title, selection.two.title, sep = " - "),
    shapes = network.edges.shapes,
    xaxis = network.graph.axis,
    yaxis = network.graph.axis
  )

  network.plot.layout
}
