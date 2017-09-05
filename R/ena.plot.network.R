
ena.plot.network = function(
  enaplot = NULL,
  network = NULL,
  title = "ENA Network",
  colors = c(pos="#e53939", "#116cff"),
  show.all.nodes = T,
  ...
  # units.by = enaset$enadata$get('units.by'),
  # group.by = enaset$enadata$get('conversations.by'), #"Condition",
  #
  # selection.one.color = "#5399c7",
  # selection.one.name = NULL,
  # selection.one.title = NULL,
  #
  # selection.two.color = "#FF0000",
  # selection.two.name = NULL,
  # selection.two.title = NULL,
  #
  # weight.multiplier = 20,
  # font.size = 10,
  # font.color = "000000",
  # font.family = "Arial",
  #
  # node.weight.multiplier = weight.multiplier,
  # node.color = "#464646",
  # node.font.size = font.size,
  # node.font.family = font.family,
  # node.font.color = font.color,
  #
  # edge.weight.multiplier = weight.multiplier,
  # edge.font.size = font.size,
  # edge.font.color = font.color,
  # edge.font.family = font.family,
  # edge.hide = NULL,
  #
  # network.edge.threshold = 0,
  # network.show.all.codes = F
) {
  if(choose(nrow(enaplot$enaset$node.positions), 2) != length(network)) {
    stop(paste0("Network vector needs to be of length ", choose(nrow(enaplot$enaset$node.positions), 2)))
  }
  args = list(...);
  # df = data.frame(enaset$points.normed.centered, unique(enaset$enadata$units), ENA_UNIT = enaset$enadata$unit.names);
  # dfDT= data.table::as.data.table(df);
  # dfDT$handle = dfDT$ENA_UNIT; #merge_columns_c(dfDT,units.by, sep="."); #rownames(df);
  #
  # units.to.plot = c(selection.one.name, selection.two.name);
  #
  # sdcols=colnames(dfDT)[sapply(dfDT, is.numeric)];
  # minDT = dfDT[handle %in% units.to.plot, lapply(.SD,sum,na.rm=T), by=units.by, .SDcols=sdcols];
  #
  # minDT$ENA_UNIT = merge.columns(x = minDT, from.cols = units.by);
  # minDT = minDT[match(ENA_UNIT, units.to.plot),];
  #
  # minDTc =minDT[,apply(.SD,2,make.network.node, types=c(selection.one.color, selection.two.color)),.SDcols=sdcols, with = T];
  # minDTsizes = minDTc[1,!is.na(minDTc[2,]), with=F];
  # minDTcolors = minDTc[2,!is.na(minDTc[2,]), with=F];
  # minDTsizes = minDTsizes[,which(!names(minDTcolors) %in% group.by),with=F];
  # minDTcolors = minDTcolors[,which(!names(minDTcolors) %in% group.by),with=F];
  # minDTnodes = minDTc[,!is.na(minDTc[2,]), with=F]
  # minDTnodes = minDTnodes[,which(!names(minDTcolors) %in% group.by),with=F]
  # minDTnodes = minDTnodes[,{ cols=strsplit(colnames(.SD), "...", fixed=T); m=as.matrix(.SD[,,with=F]); lapply(1:length(cols),function(x){ c(m[1,x],m[2,x],cols[[x]]) }); },];
  #
  # minDTnodes_trans = t(minDTnodes);
  # minDTnodes_trans = minDTnodes_trans[,c(3:4,1:2)];
  #
  # network.edges = minDTnodes_trans; #as.data.frame(get.edgelist(network.graph));
  # network.edges.table = data.table::as.data.table(network.edges);
  #
  # ## Remove edges below threshold
  # network.edges.table = network.edges.table[V3 > network.edge.threshold]
  #
  # ## Remove nodes without connections
  #
  # ## Remove edges explicitly hidden
  # if(!is.null(edge.hide)) {
  #   network.edges.table = network.edges.table[!network.edges.table$V2 %in% edge.hide|!network.edges.table$V2 %in% edge.hide,]
  # }
  # network.edges.length = nrow(network.edges.table);
  #
  # df.names = rownames(enaset$node.positions);
  # if(is.null(df.names)) {
  #   df.names = as.character(1:nrow(enaset$node.positions))
  #   rownames(enaset$node.positions) = df.names;
  # }
  # network.vertices.df = data.frame(
  #   name = df.names, ## New LWS method needs to assign names/attr
  #   enaset$node.positions
  # );
  # network.graph = igraph::graph_from_data_frame(
  #   minDTnodes_trans,
  #   directed = F,
  #   vertices = network.vertices.df
  # )
  # network.layout = enaset$node.positions;
  # network.vertices = igraph::V(network.graph);
  # network.vertices.length = length(network.vertices);
  # network.font.text = list(
  #   family = node.font.family,
  #   size = node.font.size,
  #   color = node.font.color
  # )
  #
  # network.nodes.x = network.layout[,1];
  # network.nodes.y = network.layout[,2];
  #
  network.edges.shapes = list();
  # for (i in 1:network.edges.length) {
  #   v0 <- unlist(network.edges.table[i,][[1]]); #network.edges.table[i,][[1]];
  #   v1 <- unlist(network.edges.table[i,][[2]]); #network.edges.table[i,][[2]];
  #   edge_shape = list(
  #     type = "line",
  #     line = list(
  #       color=unlist(network.edges.table[i,][[4]]), #network.edges.table[i,][[4]],
  #       width=unlist(network.edges.table[i,][[3]]) * edge.weight.multiplier #network.edges.table[i,][[3]]
  #     ),
  #     x0 = network.vertices.df[v0,]$X1, #network.nodes.x[0],
  #     y0 = network.vertices.df[v0,]$X2, #network.nodes.y[0],
  #     x1 = network.vertices.df[v1,]$X1, #network.nodes.x[1],
  #     y1 = network.vertices.df[v1,]$X2 #network.nodes.y[1]
  #   );
  #   network.edges.shapes[[i]] = edge_shape
  # }
  #
  # network.graph.axis <- list(title = "", showgrid = FALSE, showticklabels = FALSE, zeroline = T);
  # node.sizes = sapply(rownames(network.layout), function(x) { network.edges.table[V1==x|V2==x, sum(unlist(V3)),] }) * node.weight.multiplier
  #
  # if(!network.show.all.codes) {
  #   node.sizes = node.sizes[which(data.frame(node.sizes)$node.sizes != 0)]
  #   network.layout = network.layout[rownames(network.layout) %in% names(node.sizes),]
  # }
  # network.plot = plotly::plot_ly(
  #   data.frame(network.layout),
  #   type="scatter",
  #   x = ~X1,
  #   y = ~X2,
  #   mode="markers",
  #   marker = list(
  #     color = I(node.color),
  #     size = as.numeric(node.sizes)
  #   ),
  #   showlegend = F,
  #   text = rownames(network.layout)
  # );
  # network.plot = plotly::add_annotations(
  #   network.plot,
  #   textfont = network.font.text,
  #   xref = "x",
  #   yref = "y",
  #   xanchor = "center",
  #   standoff = 30,
  #   #clicktoshow = "onout",
  #   #captureevents = T,
  #   visible = F,
  #   #ax = 20, #sample(200, nrow(network.layout), replace=T),
  #   #ay = -90,
  #   showarrow = F
  #   #textposition = "top right"
  # );
  #
  # selection.one.title = stringr::str_c("<b style=\"color:",selection.one.color,"\">",selection.one.name,"</b>");
  #
  # if(!is.null(selection.two.name)) {
  #   selection.two.title = stringr::str_c("<b style=\"color:",selection.two.color,"\">",selection.two.name,"</b>");
  # }
  #

  minWeight = round(min(abs(network)[abs(network)>0]), 6);
  maxWeight = round(max(abs(network)), 6);
  minOpacity = 0.3;
  maxOpacity = 1.0;
  adjustWeight <- function(weight) {
	  (abs(weight) - minWeight) / (maxWeight - minWeight);
  }

  nodes = data.frame(enaplot$enaset$node.positions);
  nodes$weight = rep(0, nrow(nodes))
  nodes$color = "black";
  node.rows = rownames(enaplot$enaset$node.positions);
  mat = attr(enaplot$enaset$enadata$adjacency.vectors,"adjacency.matrix");

  network.scaled = network;
  if(!is.null(args$scale.weights) && args$scale.weights == T) {
    network.scaled = network * (1 / max(abs(network)));
  }

  colors.hsv = rgb2hsv(col2rgb(colors))
  if(ncol(colors.hsv) == 1) {
    colors.hsv[[4]] = colors.hsv[1] + 0.5;
    if(colors.hsv[4] > 1) {
      colors.hsv[4] = colors.hsv[4] - 1;
    }

    colors.hsv[[5]] = colors.hsv[2];
    colors.hsv[[6]] = colors.hsv[3];
    dim(colors.hsv) = c(3,2);
  }

  browser()
  for (i in 1:ncol(mat)) {
    v0 <- enaplot$enaset$node.positions[ node.rows==mat[1,i],];
    v1 <- enaplot$enaset$node.positions[ node.rows==mat[2,i],];
    nodes[node.rows==mat[,i],]$weight = nodes[node.rows==mat[,i],]$weight + network.scaled[i];

    col = NULL
    if(network.scaled[i]>0) {
      col = colors.hsv[,1];
    } else {
      col = colors.hsv[,2];
    }
    col[2] = abs(network.scaled[i]);

    edge_shape = list(
      type = "line",
      opacity = network.scaled[i], #adjustWeight(network[i]),
      line = list(
        color= hsv(col[1],col[2],col[3]), #unlist(network.edges.table[i,][[4]]), #network.edges.table[i,][[4]],
        width= abs(network.scaled[i]) * enaplot$get("multiplier") #unlist(network.edges.table[i,][[3]]) * edge.weight.multiplier #network.edges.table[i,][[3]]
      ),
      x0 = v0[1],
      y0 = v0[2],
      x1 = v1[1],
      y1 = v1[2]
    );
    network.edges.shapes[[i]] = edge_shape
  };

  nodes$color[nodes$weight >= 0] = colors[1]
  nodes$color[nodes$weight < 0] = colors[2]
  if(show.all.nodes == F) {
    nodes = nodes[-which(nodes$weight == 0),]
  }
  enaplot$plot %<>% plotly::add_trace(
    data = nodes,
    x = ~X1,
    y = ~X2,
    showlegend = F,
    mode = "markers+text",
    textposition = 'middle right',
    marker = list(
      color = "#000000", #nodes$color,
      size = abs(nodes$weight)  * enaplot$get("multiplier")  #*10
    ),
    text = rownames(nodes),
    hoverinfo = 'none'
  );
  enaplot$plot %<>% plotly::layout(
    title =  enaplot$title,
    shapes = network.edges.shapes
  );

  enaplot
}
