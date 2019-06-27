connection.matrix <- function(x, wh = x$model$unit.labels, simplify = T) {
  codes = x$rotation$codes;
  number = length(codes);

  sapply(wh, function(unit) {
    m = matrix(
      rep(NA, number^2),
      ncol =  number,
      nrow =  number,
      dimnames = list(codes, codes)
    )
    m[upper.tri(m)] = as.numeric(x$connection.counts[which(wh == unit),])
    m
  }, simplify = F)
}
