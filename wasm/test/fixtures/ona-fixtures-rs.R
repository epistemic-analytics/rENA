# Regenerates the nodes and centroids of test/fixtures/ona-model-rs.json and
# ona-sphere-norm-rs.json with the current rENA / ona (node optimization's
# self_weight). Each model is rebuilt from the recipe in the test headers and
# its units, points and variance are checked against the fixture first -- they
# do not depend on node weighting -- so only nodes and centroids change.
# PRIA fields are carried over (PRIA's removals do not use node positions).
#
#   Rscript wasm/test/fixtures/ona-fixtures-rs.R   (from the rENA root; rENA + ona installed)
suppressMessages({ library(rENA); library(ona); library(jsonlite) })

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
  key <- paste(dn, rot, sep = "_"); set <- fit(acc_of(datasets[[dn]]), rot)
  stopifnot(identical(units_of(set), unlist(fx[[key]]$units)))
  same(dims12(set$points), fx[[key]]$points, paste(key, "points"))
  if (max(abs(set$model$variance[1:2] - unlist(fx[[key]]$variance))) > 1e-9) stop(key, " variance differs")
  fx[[key]]$nodes     <- dims12(set$rotation$nodes)
  fx[[key]]$centroids <- dims12(set$model$centroids)
  cat(key, ": points/variance match; nodes, centroids updated\n")
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
