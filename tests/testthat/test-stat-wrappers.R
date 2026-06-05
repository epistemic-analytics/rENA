suppressMessages(library(rENA, quietly = TRUE, verbose = FALSE))
suppressMessages(library(libqe, quietly = TRUE))
context("ena_mean_ci / ena_outlier_ci / ena_group_stats wrappers")

# Small synthetic ENA points matrix used across all tests
set.seed(42)
POINTS <- matrix(rnorm(30 * 2), nrow = 30)
G1     <- POINTS[1:15, ]
G2     <- POINTS[16:30, ]

# ── ena_mean_ci ───────────────────────────────────────────────────────────────

test_that("ena_mean_ci: output is dims x 3", {
    out <- ena_mean_ci(POINTS)
    expect_equal(dim(out), c(2L, 3L))
})

test_that("ena_mean_ci: delegates to libqe::mean_ci", {
    expect_equal(ena_mean_ci(POINTS, 0.95),
                 libqe::mean_ci(POINTS, 0.95))
})

test_that("ena_mean_ci: lower <= mean <= upper", {
    out <- ena_mean_ci(POINTS)
    expect_true(all(out[, 2] <= out[, 1] + 1e-12))
    expect_true(all(out[, 3] >= out[, 1] - 1e-12))
})

test_that("ena_mean_ci: mean column matches colMeans", {
    out <- ena_mean_ci(POINTS)
    expect_equal(out[, 1], colMeans(POINTS), tolerance = 1e-10)
})

test_that("ena_mean_ci: higher conf_level gives wider CI", {
    w95 <- diff(ena_mean_ci(POINTS, 0.95)[1, 2:3])
    w80 <- diff(ena_mean_ci(POINTS, 0.80)[1, 2:3])
    expect_gt(w95, w80)
})

test_that("ena_mean_ci: accepts data.frame input", {
    df  <- as.data.frame(POINTS)
    out <- ena_mean_ci(df)
    expect_equal(dim(out), c(2L, 3L))
})

# ── ena_outlier_ci ────────────────────────────────────────────────────────────

test_that("ena_outlier_ci: output is dims x 2", {
    out <- ena_outlier_ci(POINTS)
    expect_equal(dim(out), c(2L, 2L))
})

test_that("ena_outlier_ci: delegates to libqe::outlier_ci", {
    expect_equal(ena_outlier_ci(POINTS, 1.5),
                 libqe::outlier_ci(POINTS, 1.5))
})

test_that("ena_outlier_ci: lower = -upper (symmetric around 0)", {
    out <- ena_outlier_ci(POINTS)
    expect_equal(out[, 1], -out[, 2], tolerance = 1e-14)
})

test_that("ena_outlier_ci: doubling iqr_factor doubles bounds", {
    out15 <- ena_outlier_ci(POINTS, 1.5)
    out30 <- ena_outlier_ci(POINTS, 3.0)
    expect_equal(out30, out15 * 2, tolerance = 1e-14)
})

test_that("ena_outlier_ci: accepts data.frame input", {
    df  <- as.data.frame(POINTS)
    out <- ena_outlier_ci(df)
    expect_equal(dim(out), c(2L, 2L))
})

# ── ena_group_stats ───────────────────────────────────────────────────────────
# libqe::group_stats returns list(N, parametric, nonparametric):
#   N             int[2]   — c(n1, n2)
#   parametric    list     — t, parameter (df), pvalue, effect (Cohen's d),
#                            mean (2 x dims), std.dev (2 x dims)
#   nonparametric list     — U, pvalue, effect (rank-biserial r),
#                            median (2 x dims)

test_that("ena_group_stats: returns list with N/parametric/nonparametric", {
    out <- ena_group_stats(G1, G2)
    expect_true(all(c("N", "parametric", "nonparametric") %in% names(out)))
})

test_that("ena_group_stats: delegates to libqe::group_stats", {
    expect_equal(ena_group_stats(G1, G2),
                 libqe::group_stats(G1, G2))
})

test_that("ena_group_stats: N gives correct group sizes", {
    out <- ena_group_stats(G1, G2)
    expect_equal(out$N[1], nrow(G1))
    expect_equal(out$N[2], nrow(G2))
})

test_that("ena_group_stats: parametric p-values are in [0, 1]", {
    out <- ena_group_stats(G1, G2)
    expect_true(all(out$parametric$pvalue >= 0 & out$parametric$pvalue <= 1))
})

test_that("ena_group_stats: nonparametric p-values are in [0, 1]", {
    out <- ena_group_stats(G1, G2)
    expect_true(all(out$nonparametric$pvalue >= 0 & out$nonparametric$pvalue <= 1))
})

test_that("ena_group_stats: parametric$mean is 2 x dims", {
    out  <- ena_group_stats(G1, G2)
    dims <- ncol(POINTS)
    expect_equal(nrow(out$parametric$mean), 2L)
    expect_equal(ncol(out$parametric$mean), dims)
})

test_that("ena_group_stats: parametric has t, df, effect per dim", {
    out  <- ena_group_stats(G1, G2)
    dims <- ncol(POINTS)
    expect_equal(nrow(out$parametric$t),         dims)
    expect_equal(nrow(out$parametric$parameter), dims)
    expect_equal(nrow(out$parametric$effect),    dims)
})

test_that("ena_group_stats: accepts data.frame input", {
    out <- ena_group_stats(as.data.frame(G1), as.data.frame(G2))
    expect_equal(out$N[1], nrow(G1))
})
