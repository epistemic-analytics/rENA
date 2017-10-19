##
# @title Accumulate and Generate
#
# @description Accumulate and Generate
#
# @details [TBD]
#
# @param file [TBD]
# @param window.size.back [TBD]
# @param units.by [TBD]
# @param conversations.by [TBD]
# @param code [TBD]
# @param units.used [TBD]
#' @export
# @return list containing the accumulation and set
##
ena.generate <- function(
  file,
  window.size.back,
  units.by,
  conversations.by,
  code,
  scale.nodes = T,
  units.used = NULL,
  ...
) {
  args = list(...);
  accum = ena.accumulate.data.file(
    file = file,
    window.size.back = window.size.back,
    units.by = make.names(units.by),
    units.used = units.used,
    model = "EndPoint",
    conversations.by = make.names(conversations.by),
    codes = make.names(code),
    ...
  )
  set = ena.make.set(
    enadata = accum,
    ...
  )


  group.names = unique(set$enadata$units[[units.by[[1]]]])
  group.cnt = length(group.names);
  conf.ints = matrix(0, nrow=(group.cnt), ncol=(2));
  outlier.ints = matrix(0, nrow=(group.cnt), ncol=(2));

  if(scale.nodes == T) {
    set$points.rotated = sapply(1:ncol(set$points.rotated), function(x) {
      minex = min(set$node.positions[,x])
      maxex = max(set$node.positions[,x])
      points = set$points.rotated[,x]
      posInds = points > 0
      points[posInds] = scales::rescale(points[posInds], c(0, maxex))
      negInds = points < 0
      points[negInds] = scales::rescale(points[negInds], c(minex, 0))
      points
    });
  }

  cis = lapply(as.character(unique(set$enadata$units[[units.by[[1]]]])), function(x) {
    pntRows = as.data.frame(set$enadata$units[[units.by[[1]]]]) == x;
    pnts = as.matrix(set$points.rotated[pntRows,])
    dim(pnts) = c(length(which(pntRows)),2)
    ci = as.numeric(t.test(pnts, conf.level = 0.95)$conf.int)
    oi = c(IQR(pnts[,1]), IQR(pnts[,2])) * 1.5
    list(ci = ci, oi = oi)
  });
  for(n in 1:length(group.names)) {
    conf.ints[n, ] = cis[[n]]$ci
    outlier.ints[n, ] = cis[[n]]$oi
  }
  groups = ena.group(set, set$enadata$units[[units.by[[1]]]])
  groups$line.weights = as.matrix(groups$line.weights)
  colnames(groups$line.weights) = NULL
  groups$conf.ints = conf.ints;
  groups$outlier.ints = outlier.ints;

  if(
    !is.null(args$output) && args$output == "save" &&
    !is.null(args$output.to)
  ) {
    setName = tools::file_path_sans_ext(basename(args$output.to))
    env = environment()
    assign(x = setName, value = set, envir = env);
    env[[setName]] = get(x = setName, envir = env)

    tmp <- tempfile(fileext = ".rdata")
    on.exit(unlink(tmp))
    save(list = c(setName), file = tmp, envir = env)
    bucket <- aws.s3::get_bucketname(args$output.to)
    object <- aws.s3:::get_objectkey.character(args$output.to)
    return(aws.s3::put_object(file = tmp, bucket = bucket, object = object));
  } else {
    nodes = data.frame(set$node.positions);
    nodes$weight = rep(0, nrow(nodes))
    node.rows = rownames(set$node.positions);

    weights = matrix(0, ncol=nrow(set$node.positions), nrow=nrow(set$line.weights));
    colnames(weights) = node.rows
    network.scaled = set$line.weights;
    # if(!is.null(scale.weights) && scale.weights == T) {
    #   network.scaled = network.scaled * (1 / max(abs(network.scaled)));
    # }

    mat = set$enadata$adjacency.matrix;
    for (x in 1:nrow(network.scaled)) {
      network.thickness = network.scaled[x,] #scales::rescale(abs(network.scaled[x,]), thickness);
      for (i in 1:ncol(mat)) {
        weights[x,node.rows==mat[1,i]] = weights[x,node.rows==mat[1,i]] + network.thickness[i];
        weights[x,node.rows==mat[2,i]] = weights[x,node.rows==mat[2,i]] + network.thickness[i];
      }
    }

    weights = t(apply(weights, 1, scales::rescale, c(1,ncol(weights))));


    return( list(
      set = set, groups = groups, scaled = scale.nodes,
      node.sizes = weights
    ));
  }
}
