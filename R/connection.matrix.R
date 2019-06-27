connection.matrix <- function(x, wh = NULL, simplify = T) {
  # codes = x$rotation$codes;
  codes = unique(as.vector(attr(x, which = "adjacency.matrix")))
  number = length(codes);
  if(is.null(wh)) {
    all.units = attr(x, which = "ena.unit.names")
    wh = unlist(all.units[, do.call(paste, c(.SD, sep = ".")), by = seq_len(nrow(all.units))][,2])
  }

  cm = sapply(wh, function(unit) {
    m = matrix(
      rep(NA, number^2),
      ncol =  number,
      nrow =  number,
      dimnames = list(codes, codes)
    )
    m[upper.tri(m)] = as.numeric(x[which(wh == unit),])
    m
  }, simplify = F);
  names(cm) = wh;
  return(cm);
}
