ena.plot.network = function(
  enaplot = NULL,
  network = NULL,
  colors = c(pos="#e53939", "#116cff"),
  show.all.nodes = T,
  threshold = 0.0,
  thin.lines.in.front = T,
  opacity = c(0.3,1),
  saturation = c(0.25,1),
  thickness = c(0,1),
  node.size = c(1,20),
  range = c(min(network), max(network)),
  labels = rownames(enaplot$enaset$node.positions),
  label.offset = NULL,
  label.font.size = enaplot$get("font.size"),
  label.font.color = enaplot$get("font.color"),
  label.font.family = enaplot$get("font.family"),
  ...
) {
  if(choose(nrow(enaplot$enaset$node.positions), 2) != length(network)) {
    stop(paste0("Network vector needs to be of length ", choose(nrow(enaplot$enaset$node.positions), 2)))
  }
  args = list(...);
  network.edges.shapes = list();

  nodes = data.frame(enaplot$enaset$node.positions);
  nodes$weight = rep(0, nrow(nodes))
  nodes$color = "black";
  node.rows = rownames(enaplot$enaset$node.positions);

  network.scaled = network;
  if(!is.null(args$scale.weights) && args$scale.weights == T) {
    network.scaled = network * (1 / max(abs(network)));
  }

  pos.inds = as.numeric(which(network.scaled >=0));
  neg.inds = as.numeric(which(network.scaled < 0));
  network.opacity = scales::rescale(abs(network.scaled), opacity);
  network.saturation = scales::rescale(abs(network.scaled), saturation);
  network.thickness = scales::rescale(abs(network.scaled), thickness);

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

  mat = attr(enaplot$enaset$enadata$adjacency.vectors.raw,"adjacency.matrix");
  for (i in 1:ncol(mat)) {
    v0 <- enaplot$enaset$node.positions[ node.rows==mat[1,i],];
    v1 <- enaplot$enaset$node.positions[ node.rows==mat[2,i],];
    nodes[node.rows==mat[,i],]$weight = nodes[node.rows==mat[,i],]$weight + network.thickness[i];

    color = NULL
    if(i %in% pos.inds) {
      color = colors.hsv[,1];
    } else {
      color = colors.hsv[,2];
    }
    color[2] = network.saturation[i];

    edge_shape = list(
      type = "line",
      opacity = network.opacity[i],
      nodes = c(mat[,i]),
      line = list(
        name = "test",
        color= hsv(color[1],color[2],color[3]),
        width= network.thickness[i] * enaplot$get("multiplier")
      ),
      x0 = v0[1],
      y0 = v0[2],
      x1 = v1[1],
      y1 = v1[2],
      layer = "below",
      size = as.numeric(abs(network.scaled[i]))
    );
    network.edges.shapes[[i]] = edge_shape
  };

  if(thin.lines.in.front) {
    network.edges.shapes = network.edges.shapes[rev(order(sapply(network.edges.shapes, "[[", "size")))]
  } else {
    network.edges.shapes = network.edges.shapes[order(sapply(network.edges.shapes, "[[", "size"))]
  }
  if(threshold > 0) {
    network.edges.shapes = network.edges.shapes[sapply(network.edges.shapes, "[[", "size") > threshold];
  }
  if(show.all.nodes == F) {
    nodes = nodes[rownames(nodes) %in% unique(as.character(sapply(network.edges.shapes, "[[", "nodes"))), ]
  }
  mode = "markers+text"
  if(!is.null(args$labels.hide) && args$labels.hide == T) {
    mode="markers"
  }
  nodes$weight = scales::rescale((nodes$weight * (1 / max(abs(nodes$weight)))), node.size) # * enaplot$get("multiplier"));
  enaplot$plot = plotly::add_trace(
    enaplot$plot,
    data = nodes,
    x = ~X1,
    y = ~X2,
    mode = mode,
    textposition = 'middle right',
    marker = list(
      color = "#000000",
      size = abs(nodes$weight),
      name = rownames(nodes)[i]
    ),
    text = rownames(nodes),
    hoverinfo = 'none'
  );
  enaplot$plot = plotly::layout(
    enaplot$plot,
    title =  enaplot$title,
    shapes = network.edges.shapes,
    showlegend = F
  );

  enaplot
}
