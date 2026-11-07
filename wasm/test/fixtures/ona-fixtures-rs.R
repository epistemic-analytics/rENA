# Regenerates test/fixtures/ona-model-rs.json and ona-sphere-norm-rs.json with
# the current rENA / ona source (this checkout's rENA and the ona checkout next
# to it, so a fix in rENA's model() is in the fixture before it is installed).
# Each model is rebuilt from the recipe in the test headers. For the datasets
# without an empty network (rs, and ona-sphere-norm) the units, points and
# variance are checked against the fixture first -- they do not depend on node
# weighting -- so only nodes and centroids change, and PRIA fields are carried
# over. For rs_zero (one all-zero unit, "zero user") everything is refreshed:
# the zero-network rule of rENA 0.4.17 (the empty unit stays at the origin and
# is left out of the centering, rotation and node fit) moves its points and
# rotation too.
#
#   Rscript wasm/test/fixtures/ona-fixtures-rs.R   (from the rENA root; ../ona checked out)
suppressMessages({
  pkgload::load_all(".", quiet = TRUE)
  pkgload::load_all("../ona", quiet = TRUE)
  library(jsonlite)
})

x <- read.csv("inst/extdata/rs.data.csv")
codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
           "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
zero <- head(x[x$Condition == "FirstGame" & x$GroupName == 2, ], 3)
zero$UserName <- "zero user"; zero[, codes] <- 0
datasets <- list(rs = x, rs_zero = rbind(x, zero))

acc_of <- function(d) rENA::accumulate(d, c("Condition", "UserName"), codes,
                                       c("Condition", "GroupName"), default_window = 4, ordered = TRUE)
fit <- function(acc, rot, ...) {
  if (rot == "svd") return(ona::model(acc, ...))
  cond <- acc$meta.data$Condition
  ona::model(acc, ..., rotate.using = "mean",
             rotation.params = list(FirstGame = cond == "FirstGame", SecondGame = cond == "SecondGame"))
}
dims12 <- function(m) unname(as.matrix(m)[, 1:2, drop = FALSE])
units_of <- function(set) paste(set$meta.data$Condition, set$meta.data$UserName, sep = "::")
same <- function(a, b, what) {
  a <- as.matrix(a); b <- matrix(unlist(b), nrow = length(b), byrow = TRUE)
  d <- max(abs(a - b)); if (d > 1e-9) stop(what, " differs from the fixture by ", d)
}

# ona-model-rs.json
f <- "wasm/test/fixtures/ona-model-rs.json"; fx <- fromJSON(f, simplifyVector = FALSE)
for (dn in names(datasets)) for (rot in c("svd", "mean")) {
  key <- paste(dn, rot, sep = "_"); acc <- acc_of(datasets[[dn]]); set <- fit(acc, rot)
  stopifnot(identical(units_of(set), unlist(fx[[key]]$units)))
  if (dn == "rs_zero") {
    stopifnot(sum(rowSums(as.matrix(set$line.weights)) == 0) == 1)
    fx[[key]]$points   <- dims12(set$points)
    fx[[key]]$variance <- unname(as.numeric(set$model$variance)[1:2])
    rb <- function(a) fit(a, rot)
    removed <- PRIA::pria(set, remove.num = 3, threshold = 0.95, rebuild = rb)
    fx[[key]]$pria_removed  <- as.character(removed)
    fx[[key]]$pria_variance <- unname(as.numeric(PRIA:::get_pria_scores_2Ds(set, removed, rebuild = rb)$vr1))
    cat(key, ": points, variance, nodes, centroids and PRIA updated\n")
  } else {
    same(dims12(set$points), fx[[key]]$points, paste(key, "points"))
    if (max(abs(set$model$variance[1:2] - unlist(fx[[key]]$variance))) > 1e-9) stop(key, " variance differs")
    cat(key, ": points/variance match; nodes, centroids updated\n")
  }
  fx[[key]]$nodes     <- dims12(set$rotation$nodes)
  fx[[key]]$centroids <- dims12(set$model$centroids)
}
write_json(fx, f, digits = NA, auto_unbox = TRUE)

# ona-sphere-norm-rs.json
f <- "wasm/test/fixtures/ona-sphere-norm-rs.json"; fx <- fromJSON(f, simplifyVector = FALSE)
acc <- acc_of(x)
for (sn in c("TRUE", "FALSE")) for (rot in c("svd", "mean")) {
  norm <- if (sn == "TRUE") rENA::sphere_norm else rENA::skip_sphere_norm
  set <- fit(acc, rot, normalize = norm); e <- fx[[paste0("sphere_", sn)]][[rot]]
  same(dims12(set$points), e$points, paste("sphere", sn, rot, "points"))
  fx[[paste0("sphere_", sn)]][[rot]]$nodes     <- dims12(set$rotation$nodes)
  fx[[paste0("sphere_", sn)]][[rot]]$centroids <- dims12(set$model$centroids)
  cat("sphere_", sn, " ", rot, ": points match; nodes, centroids updated\n", sep = "")
}
write_json(fx, f, digits = NA, auto_unbox = TRUE)
