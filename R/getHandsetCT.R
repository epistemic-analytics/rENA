#
#
#
#
# gold1s = rep(x = 1, times = goldPs)
#
# sample.int(n = goldPs, )
#
#
# hsl = 30
# br = 0.2
#
# silver.when.gold1 = c(rep(1,tp),rep(0,fn))
# pos = sample(x = silver.when.gold1, size = (hsl * br), replace = F, prob = c(rep(tp/goldPs, tp), rep(fn/goldPs, fn)))
#
#
# less.tp = length(which(pos == 1))
# less.fn = length(which(pos == 0))
# silver.less.inflation = c(rep(0,tn30),rep(1,fp))
# neg = sample(x = silver.less.inflation, size = (hsl * (1-br)), replace = F, prob = c(rep(tn/goldNs, tn), rep(fp/goldNs, fp)))


getHandsetCT = function(ct, hsl = 20, br = 0.2) {
  tp = ct[1,1]
  fp = ct[2,1]
  tn = ct[2,2]
  fn = ct[1,2]
  N = sum(ct)

  goldPs = sum(ct[1,])
  goldNs = sum(ct[2,])
  silverPs = sum(ct[,1])
  silverNs = sum(ct[,2])

  inflatedProb = c(tp/goldPs, fn/goldPs)
  inflatedLen = hsl * br
  inflated = sample.int(n = 2, size = inflatedLen, replace = T, prob = inflatedProb)
  inflatedTPs = length(which(inflated == 1))
  inflatedFNs = length(which(inflated == 2))

  leftN = N - inflatedLen
  othersLen = (hsl * (1 - br))
  othersTP = (tp - inflatedTPs)
  othersFN = (fn - inflatedFNs)
  othersProb = c( othersTP/leftN, othersFN/leftN, fp/leftN, tn/leftN )
  others = sample.int(n = 4, size = othersLen, prob = othersProb, replace = T)
  otherTPs = length(which(others == 1))
  otherFNs = length(which(others == 2))
  otherFPs = length(which(others == 3))
  otherTNs = length(which(others == 4))
  handsetMatrix = matrix(c((inflatedTPs+otherTPs),(inflatedFNs+otherFNs),otherFPs, otherTNs), ncol=2, byrow=T)
  # browser()
  return(rhoR:::contingencyToSet( (inflatedTPs+otherTPs),otherFPs, (inflatedFNs+otherFNs), otherTNs))
}


# ct = matrix(c(20,5,5,20), ncol=2)
