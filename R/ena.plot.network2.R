
ena.plot.network2 = function(
  enaplot = NULL,
  network = enaplot$enaset$line.weights,
  method = mean,
  colors = c("red", "blue"),
  show.all.nodes = T,
  label.offset = NULL, #### NOT AN OPTION FOR HOVERTEXT

  threshold = c(0, 1),
  opacity = c(0.3, 1),
  saturation = c(0.25, 1),
  thickness = c(0, 1),
  range = c(set.min, set.max),
  thin.lines.in.front = T,

  ##### OLD PARAMS
  units.by = enaplot$enaset$enadata$get('units.by'),
  group.by = enaplot$enaset$enadata$get('conversations.by'), #"Condition",

  selection.one.name = NULL,
  selection.one.color = "#5399c7",
  selection.one.title = NULL,

  selection.two.name = NULL,
  selection.two.color = "#FF0000",
  selection.two.title = NULL,

  weight.multiplier = 20,
  font.size = enaplot$font.size,
  font.color = enaplot$font.color,
  font.family = enaplot$font.family,

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
  ####### NEW
  ### if network for more than one unit, reduce to one row using method
  if(nrow(network) > 1) {
    network = colMeans(network);
  }
  ### if given network 2 and it has more than one unit, reduce to one row using method
  # if(!is.null(network2) && nrow(network2) > 1) {
  #   network2 = colMeans(network2);
  # }

  codeWeights = data.frame(matrix(NA, ncol = length(enaplot$enaset$codes)));
  names(codeWeights) = enaplot$enaset$codes;
  ### nested for loop, for each code find its adj codes and sum them, remove ones with all zero
  for(code in names(codeWeights)) {
    codeSum = 0;
    adjIndex = 1;

    for(adj.code in network) {
      ### if adj.code column corresponds to code - add column's value to the codeSum
      if(grepl(code, names(network)[adjIndex])) {
        codeSum <- codeSum + adj.code;
      }
      adjIndex = adjIndex + 1;
    }

    codeWeights[,code] <- codeSum;
  }

  ### if not showing all nodes remove nodes with value of zero
  if(!show.all.nodes) {
    for(col in names(codeWeights)) {
      #print(col)
      if(codeWeights[,col] == 0) codeWeights[,col] <- NULL;
    }
  }

  ###### END NEW

  df = data.frame(enaplot$enaset$line.weights, attr(enaplot$enaset$line.weights, rENA::opts$UNIT_NAMES));

  dfDT= data.table::as.data.table(df);

  #dfDT$handle = merge_columns_c(dfDT, units.by, sep="."); #rownames(df);

  units.to.plot = c(selection.one.name, selection.two.name);

  sdcols=colnames(dfDT)[sapply(dfDT, is.numeric)];

  minDT = dfDT[handle %in% units.to.plot, lapply(.SD,sum,na.rm=T), by=units.by, .SDcols=sdcols];

  minDT$ENA_UNIT = merge.columns(x = minDT, from.cols = units.by);
  minDT = minDT[match(ENA_UNIT, units.to.plot),];

  minDTc = minDT[,apply(.SD,2,make.network.node, types=c(selection.one.color, selection.two.color)),.SDcols=sdcols, with = T];
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

  df.names = rownames(enaplot$enaset$node.positions);
  if(is.null(df.names)) {
    df.names = as.character(1:nrow(enaplot$enaset$node.positions))
    rownames(enaplot$enaset$node.positions) = df.names;
  }
  network.vertices.df = data.frame(
    name = df.names, ## New LWS method needs to assign names/attr
    enaplot$enaset$node.positions
  );
  network.graph = igraph::graph_from_data_frame(
    minDTnodes_trans,
    directed = F,
    vertices = network.vertices.df
  )
  network.layout = enaplot$enaset$node.positions;
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

  enaplot$plot %<>% plotly::add_markers(
    data = data.frame(network.layout),
    x = ~X1,
    y = ~X2,
    marker = list(
      color = I(node.color),
      size = as.numeric(node.sizes)
    ),
    showlegend = F,
    text = rownames(network.layout)
  );

  ### ADD ANNOTATIONS
  enaplot$plot %<>% plotly::add_annotations(
    text = rownames(network.layout),
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

  enaplot$plot %<>% plotly::layout(
    title =  stringr::str_c(selection.one.title, selection.two.title, sep = " - "),
    shapes = network.edges.shapes,
    xaxis = network.graph.axis,
    yaxis = network.graph.axis
  )

  enaplot;
}
