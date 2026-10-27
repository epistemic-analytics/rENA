# Reference for julia/test/models.jl: rENA's stanza accumulation
# (ena.accumulate.data) and models (ena.make.set) of RS.data -- SVD, means and
# generalized rotations. Writes ena-rs.json (the data columns used, and R's
# results). From the repo root:  Rscript julia/test/fixtures/ena-rs.R
suppressMessages(devtools::load_all(quiet = TRUE))
data(RS.data)
codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
           "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
cols <- c("UserName", "Condition", "ActivityNumber", "GroupName",
          "CONFIDENCE.Pre", "CONFIDENCE.Change", codes)
d <- as.data.frame(RS.data)[, cols]
# A unit-level variable with more than two groups, for select_2_groups
# (Condition has only two): CONFIDENCE.Pre (constant per unit) binned.
d$ConfidenceLevel <- c("4" = "low", "5" = "low", "6" = "mid", "7" = "high")[d$CONFIDENCE.Pre]
d$ConfidenceLevel[is.na(d$ConfidenceLevel)] <- "unknown"

acc <- ena.accumulate.data(
  units = d[, c("UserName", "Condition")],
  conversation = d[, c("ActivityNumber", "GroupName")],
  metadata = d[, c("CONFIDENCE.Pre", "CONFIDENCE.Change", "ConfidenceLevel")],
  codes = d[, codes], window.size.back = 4)
units <- paste(acc$meta.data$UserName, acc$meta.data$Condition, sep = "::")

m <- function(x) unname(as.matrix(x))
case <- function(set) list(
  line_weights = m(set$line.weights),
  points       = m(set$points)[, 1:2],
  rotation     = m(set$rotation.matrix)[, 1:2],
  nodes        = m(set$rotation$nodes)[, 1:2],
  centroids    = m(set$model$centroids)[, 1:2],
  variance     = unname(as.numeric(set$model$variance)),
  eigenvalues  = if (is.null(set$rotation$eigenvalues)) NULL else unname(as.numeric(set$rotation$eigenvalues)),
  center_vec   = unname(as.numeric(set$rotation$center.vec)))
make <- function(...) suppressWarnings(ena.make.set(acc, ...))
gmr <- function(...) make(rotation.by = ena.rotate.by.generalized, rotation.params = list(...))

out <- list(
  generator = "julia/test/fixtures/ena-rs.R",
  rENA = as.character(packageVersion("rENA")),
  data = d, codes = codes, units = units,
  connection_counts = m(as.matrix(acc$connection.counts)),
  svd = case(make()),
  means = case(make(rotation.by = ena.rotate.by.mean, rotation.params = list(
    acc$meta.data$Condition == "FirstGame", acc$meta.data$Condition == "SecondGame"))),
  gmr_categorical = case(gmr(x_var = "Condition")),
  gmr_numeric     = case(gmr(x_var = "CONFIDENCE.Change")),
  gmr_covariate   = case(gmr(x_var = c("Condition", "CONFIDENCE.Pre"))),
  gmr_y           = case(gmr(x_var = "Condition", y_var = "CONFIDENCE.Change")),
  gmr_multigroup  = case(gmr(x_var = "ConfidenceLevel")),
  gmr_select_2    = case(gmr(x_var = "ConfidenceLevel", select_2_groups = c("low", "high")))
)
jsonlite::write_json(out, "julia/test/fixtures/ena-rs.json", digits = NA, auto_unbox = TRUE,
                     dataframe = "columns", matrix = "rowmajor", null = "null")
