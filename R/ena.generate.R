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
    units.by = units.by,
    units.used = units.used,
    conversations.by = conversations.by,
    codes = code,
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
    pnts = set$points.rotated[set$enadata$units[[units.by[[1]]]] == x,]
    ci = as.numeric(t.test(pnts, conf.level = 0.95)$conf.int)
    oi = c(IQR(pnts[,1]), IQR(pnts[,2])) * 1.5
    list(ci = ci, oi = oi)
  });
  for(n in 1:length(group.names)) {
    conf.ints[n, ] = cis[[n]]$ci
    outlier.ints[n, ] = cis[[n]]$oi
  }

  groups = ena.group(set, set$enadata$units[[units.by[[1]]]])
  print("Groups should be line.weights as an array of values")
  groups$conf.ints = conf.ints;
  groups$outlier.ints = outlier.ints;
  return( list(set = set, groups = groups, scaled = scale.nodes));
}
