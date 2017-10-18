##
# @title Group Stats
#
# @description Generate comparison stats for groups within set
#
# @details [TBD]
#
# @param points [TBD]
# @param groups [TBD]
#
#' @export
# @return list containing all of the statistics
##
group.stats <- function(groupOne, groupTwo) {
  if(is.character(groupOne) && is.character(groupTwo)) {
    pnts.one = as.data.frame(set$enadata$units[[units.by[[1]]]]) == as.vector(group.names[1])
    pnts.two = as.data.frame(set$enadata$units[[units.by[[1]]]]) == as.vector(group.names[2])
    groupOne = as.matrix(set$points.rotated[pnts.one,])
    groupTwo = as.matrix(set$points.rotated[pnts.two,])
    dim(groupOne) = c(length(which(pnts.one)),2)
    dim(groupTwo) = c(length(which(pnts.two)),2)
  }

  cis = lapply((1:ncol(groupOne)), function(x) {
    ci = NA; eff = NA; std.dev = NA; mw = NA; med = NA;
    if(length(groupOne) > 0 && length(groupTwo) > 0) {
      if(length(groupOne[,x]) > 1 && length(groupTwo[,x]) > 1) {
        ci = t.test(groupOne[,x], groupTwo[,x], conf.level = 0.95)
      }
      mw = wilcox.test(groupOne[,x], groupTwo[,x], conf.level = 0.95)
      med = c(median(groupOne[,x]), median(groupTwo[,x]))
      eff = cohens.d(groupOne[,x], groupTwo[,x])
      std.dev = c(sd(groupOne[,x]), sd(groupTwo[,x]))

      return(list(ci = ci, effect = eff, std.dev = std.dev, mw = mw, median = med))
    } else {
      return(NA)
    }
  })

  toret = list(
    # names = xx,
    N = c(nrow(groupOne), nrow(groupTwo)),
    effect = c(NA,NA),
    parametric = list(
      t = c(NA,NA),
      pvalue = c(NA,NA),
      mean = matrix(0, nrow=2, ncol=2),
      std.dev = matrix(0, nrow=2, ncol=2)
    ),
    nonparametric = list(
      U = c(NA,NA),
      pvalue = c(NA,NA),
      median = matrix(0, nrow=2, ncol=2)
    )
  )

  if(length(groupOne) > 0 && length(groupTwo) > 0 ) {
    for(i in 1:2) {
    # lapply(1:2, function(i) {
      if(is(cis[[i]]$ci, "htest")) {
        toret[["parametric"]][["t"]][i] = cis[[i]]$ci$statistic
        toret[["parametric"]][["pvalue"]][i] = cis[[i]]$ci$p.value
        toret[["parametric"]][["mean"]][i,] = cis[[i]]$ci$estimate
      }
      toret$parametric[["std.dev"]][i,] = cis[[i]]$std.dev

      if(is(cis[[i]]$mw, "htest")) {
        toret[["nonparametric"]][["U"]][i] = cis[[i]]$mw$statistic
        toret[["nonparametric"]][["pvalue"]][i] = cis[[i]]$mw$p.value
      }
      toret[["nonparametric"]][["median"]][i,] = cis[[i]]$median
      # browser()
    }#)
    toret[["effect"]] = c(cis[[1]]$effect, cis[[2]]$effect)
  }

  return(toret)
}
#combn( c(groups$names,"ThirdGame"), 2, FUN = group.stats)
