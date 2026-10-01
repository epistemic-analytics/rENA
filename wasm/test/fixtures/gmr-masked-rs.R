# Run from the rENA repo root: Rscript wasm/test/fixtures/gmr-masked-rs.R [libqe-lib-path]
# Masked-GMR reference for rena-wasm. Needs libqe with the complete_rotation
# null-space fix (libqe > 0.1.5): pass its library path as the first argument.
args <- commandArgs(TRUE); if (length(args)) .libPaths(c(args[1], .libPaths()))
suppressPackageStartupMessages({ library(libqe); pkgload::load_all(".", quiet = TRUE); library(data.table); library(jsonlite) })
x <- read.csv("inst/extdata/rs.data.csv")
codes <- c("Data","Technical.Constraints","Performance.Parameters","Client.and.Consultant.Requests","Design.Reasoning","Collaboration")
acc <- ena.accumulate.data(units = x[, c("Condition","UserName")], conversation = x[, c("Condition","GroupName")], codes = x[, codes], window.size.back = 4)
acc$connection.counts[["Data & Technical.Constraints"]] <- as.ena.co.occurrence(rep(0, nrow(acc$connection.counts)))
set.seed(1)
g <- ena.make.set(acc, rotation.by = ena.rotate.by.generalized, rotation.params = list(x_var = "Condition", select_2_groups = c("FirstGame","SecondGame")))
G <- crossprod(as.matrix(g$rotation.matrix))
stopifnot(max(abs(G[upper.tri(G)])) < 1e-10)   # guard: generated with the fixed libqe
write_json(list(libqe = as.character(packageVersion("libqe")), units = as.character(g$model$unit.labels),
                points = unname(as.matrix(g$points))[, 1:2], variance = unname(as.numeric(g$model$variance))[1:4]),
           "wasm/test/fixtures/gmr-masked-rs.json", digits = NA)
cat("ok\n")
