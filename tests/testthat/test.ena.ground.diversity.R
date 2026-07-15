suppressMessages(library(rENA, quietly = TRUE, verbose = FALSE))
context("Test ground diversity window suggestion")

make_sparse <- function(n = 200, nconv = 10, p = 0.08, seed = 2) {
  set.seed(seed)
  data.frame(
    ConversationID = rep(paste0("C", seq_len(nconv)), each = n / nconv),
    A = rbinom(n, 1, p), B = rbinom(n, 1, p),
    C = rbinom(n, 1, p), D = rbinom(n, 1, p)
  )
}
codes <- c("A", "B", "C", "D")

test_that("ena.gd.window returns a single window and finds an interior peak", {
  d <- make_sparse()
  w <- ena.gd.window(d, codes, "ConversationID", max_window = 20)

  testthat::expect_length(w, 1)
  testthat::expect_true(w >= 1 && w <= 20)
  # sparse codes produce an interior entropy peak, not one pinned at window = 1
  testthat::expect_gt(w, 1)
})

test_that("ena.ground.diversity returns curves, peaks and conversation_curves", {
  d <- make_sparse()
  gd <- ena.ground.diversity(d, codes, "ConversationID", max_window = 10)

  testthat::expect_named(gd, c("curves", "peaks", "conversation_curves"))
  testthat::expect_equal(nrow(gd$curves), 10)         # one row per window
  testthat::expect_equal(nrow(gd$peaks), 1)           # single (mean) method
  # n_obs is the conversation length, so it sums back to the row count
  n_by_conv <- gd$conversation_curves[window == 1, n_obs]
  testthat::expect_equal(sum(n_by_conv), nrow(d))
})

test_that("non-binary code columns are rejected", {
  d <- make_sparse()
  d$A[1:5] <- 2L
  testthat::expect_error(
    ena.ground.diversity(d, codes, "ConversationID", max_window = 5),
    "binary"
  )
})

test_that("frollsum ground types match a plain-R rolling-max reference", {
  # A deterministic, hand-checkable multi-conversation fixture.
  d <- data.frame(
    ConversationID = rep(c("C1", "C2"), each = 7),
    A = c(0, 1, 0, 0, 1, 1, 0,  1, 0, 0, 1, 0, 0, 0),
    B = c(1, 0, 0, 1, 0, 1, 0,  0, 0, 1, 0, 1, 1, 0)
  )
  cn <- c("A", "B")

  # Reference: explicit right-aligned rolling max per code, then bit-encode.
  manual_counts <- function(d, codes, convcol, max_window) {
    bw <- 2^(seq_along(codes) - 1)
    out <- list()
    for (w in seq_len(max_window)) {
      per_window <- list()
      for (cv in unique(d[[convcol]])) {
        idx <- which(d[[convcol]] == cv)
        rolled <- vapply(codes, function(cc) {
          col <- d[[cc]][idx]
          vapply(seq_along(col),
                 function(i) max(col[max(1, i - w + 1):i]), numeric(1))
        }, numeric(length(idx)))
        gt <- as.vector(as.matrix(rolled) %*% bw)
        tab <- as.data.frame(table(ground_type = gt), stringsAsFactors = FALSE)
        tab$count <- tab$Freq
        per_window[[cv]] <- sort(tab$count)
      }
      out[[w]] <- sort(unname(unlist(per_window)))
    }
    out
  }

  ref <- manual_counts(d, cn, "ConversationID", 4)

  got <- rENA:::ground.type.counts(d, cn, "ConversationID", max_window = 4)
  for (w in 1:4) {
    counts_w <- sort(got[window == w, count])
    testthat::expect_equal(counts_w, ref[[w]], info = paste("window", w))
  }
})

test_that("runs on the packaged RS.data", {
  data(RS.data)
  codenames <- c(
    "Data", "Technical.Constraints", "Performance.Parameters",
    "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration"
  )
  w <- ena.gd.window(RS.data, codenames,
                     conversation_cols = c("ActivityNumber", "GroupName"),
                     max_window = 10)
  testthat::expect_length(w, 1)
  testthat::expect_true(w >= 1 && w <= 10)
})
