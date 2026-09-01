## Test environments
* macOS Sonoma (aarch64-apple-darwin25.0.0), R 4.5.2
* win-builder (R-release, R-devel)
* local tests (macOS, R 4.5.2)

## R CMD check results
There were 0 errors | 0 warnings | 0 notes.

## Downstream dependencies
There are no reverse dependency issues.

## Submission Summary: rENA 0.4.3
This is a patch release addressing inaccuracies in the window size estimation algorithm (`ena.tune.window.size`). There are no breaking changes to the outward-facing methods or API.

### Summary of changes:
* Fixed inaccurate window size estimation in `ena.tune.window.size()` by adopting the Cross-Covariance Decay (CCD) algorithm (Shaffer & Cai, 2026), providing more accurate and unit-agnostic window estimation.
* Added supporting helper functions `ena.ccd.window()`, `ena.ccd()`, and S3 diagnostic methods `plot.ena.ccd()`, `print.ena.ccd()`.
* Preserved legacy SVD stability behavior via `method = "stability"`.
* Improved accumulation re-evaluation robustness when `ena.tune.window.size()` is invoked in scripted or nested evaluation environments.
* Minor documentation, imports, and global variable binding fixes.