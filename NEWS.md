## rENA 0.4.7

#### Bug Fixes & Improvements

  * No changes to the R package; this release publishes rena-wasm 0.1.6
    (`@qe-libs/rena-wasm`) with fixes to `pria()`, which now matches R's
    `PRIA::pria()`:
    - The tie-break between candidates that remove the same number of codes
      now uses the reduced model's dimension-1 share of the points' variance
      across all dimensions (R's `model$variance[1]`). It previously used the
      eigenvalue ratio, which is 0 for means and GMR rotations, so the
      tie-break never applied to them.
    - Removed codes' connections are dropped rather than zeroed, as in R, so
      GMR-rotated candidates are scored correctly.
    - The data are accumulated once rather than once per candidate, making
      PRIA about 30 times faster (RS.data: 3.4 s to about 0.1 s).
    - `weightModel`, `tensor` and the caller's `codeMask` are now used, so
      PRIA scores the same model `fit()` builds.
    - For ordered (ONA) models, PRIA scores candidates with directed node
      positions, as R's ordered pipeline (`optimize()`) does. PRIA now matches
      R for ONA and transmodal (TMA) models as well as ENA. Models built by
      `fit()` are unchanged.

## rENA 0.4.6

#### Bug Fixes & Improvements

  * No changes to the R package; this release publishes rena-wasm 0.1.5
    (`@qe-libs/rena-wasm`), which missed the 0.4.5 release:
    - Weight models (`weightModel`: `"product"`, `"sqrt"`, `"log"`) are now
      applied by libqe's shared `finalize_row_connections` kernel (requires
      `@qe-libs/libqe-wasm` 0.1.5 or newer), replacing rena-wasm's own
      JavaScript copy. Results are unchanged.
    - `accumulate()` now honours `weightModel` (it was previously ignored), and
      `tuneWindowSize()` carries it through its rebuilds.
    - `"log1p"` is accepted as an alias of `"log"`.

## rENA 0.4.5

#### New Features

  * `accumulate()` gains `weight_by`, the weight model applied to each line's
    connection counts before they are summed per unit (the same stage as
    `weight.by` in `ena.accumulate.data()`): `"binary"`, `"product"` (raw,
    non-binarized counts), `"sqrt"` or `"log1p"` (alias `"log"`). For ordered
    networks the weight is applied to each directed cell, and `"binary"` keeps
    the raw directed counts. It defaults from `binary`, so existing calls are
    unchanged; on RS.data the results match `ena.accumulate.data(weight.by = ...)`
    exactly for all four weight models.

#### Bug Fixes & Improvements

  * `ena.ccd()` delegates its cross-covariance decay core to libqe's shared
    `ccd_window` kernel.
  * Removed leftover debug output: `"Using custom rotation.set."` when a
    custom rotation set is supplied, and `"- using custom V matrix"` in
    `with.ena.matrix()`.
  * Removed unused internal code (empty stub functions, an entirely
    commented-out `ena.generate()`, unused `gmr()` backups, and stale Rcpp
    headers).
  * Updated the R package dependencies to require tma 0.3.4 or newer (for
    `weight_by`) and libqe 0.1.3 or newer.

## rENA 0.4.4

#### Bug Fixes & Improvements

  * Restored polynomial trajectory smoothing and animated trajectory plotting
    against the shared libqe trajectory kernels.
  * Updated the R package dependencies to require tma 0.3.3 or newer and libqe
    0.1.2 or newer. rENA now delegates polynomial trajectory fitting for plots
    to TMA's trajectory wrapper while TMA delegates the shared numerical kernels
    to libqe.
  * Separated the legacy ENA trajectory plotting path from the newer ETM-style
    polynomial curve bridge with internal helper functions and focused
    documentation.

## rENA 0.4.3

#### Bug Fixes & Improvements

  * **Window Size Estimation (`ena.tune.window.size`)**:
    - Fixed inaccurate window size estimation by replacing the heuristic SVD
      stability plateau method with the Cross-Covariance Decay (CCD) algorithm
      (Shaffer & Cai, 2026). The function's outward-facing API and usage remain
      unchanged.
    - Added helper functions `ena.ccd.window()` and `ena.ccd()` along with S3
      methods (`plot.ena.ccd`, `print.ena.ccd`) for direct window estimation and
      diagnostic curve plotting.
    - Preserved legacy SVD stability behavior via `method = "stability"`.
    - Fixed issue where accumulation call re-evaluation failed when
      `ena.tune.window.size()` was called in scripted or nested evaluation environments.
  * Corrected `@importFrom stats` declarations in `ena_space_dist_corr.R`.
  * Updated `ENAplot` documentation and internal variable bindings in `zzz.R`.

## rENA 0.4.2

#### Improvements

  * Synchronized ENA pipeline and parameter detection with WebAssembly runtime.
  * Undirected code masking index mapping updates.

## rENA 0.4.1

#### Patch

  * `$.ena.points` and `$.ena.matrix` return `NULL` for a column that is not
    present, matching base `$`, instead of raising "attempt to select less than
    one element in get1index". Callers can now test for an optional column
    (e.g. `ENA_DIRECTION`) the ordinary way. Duplicate column names take the
    first match rather than recursively indexing on a vector.
  * `ena.correlations` indexes its per-dimension difference matrices by
    position. They are built with one column per requested dimension, so
    indexing by the caller's dimension numbers only worked for the default
    `c(1,2)`; any other pair errored with "subscript out of bounds".

## rENA 0.4.0

#### Features

  * Ground-diversity window-size suggestion, see `?ena.gd.window` and
    `?ena.ground.diversity` (R/ena.ground.diversity.R). Suggests a sliding
    window size by locating the peak normalized Shannon entropy of "ground
    types" (bit-encoded combinations of active codes) across window sizes.

## rENA 0.3.1

#### Patch

  * Update to C++ source to handle notes here: https://www.stats.ox.ac.uk/pub/bdr/C++20/README.txt

## rENA 0.3.0

#### Features

  * Generalized means rotations, see ?ena.rotate.by.generalized (R/ena.rotate.by.generalized.R)


## rENA 0.2.5 

## rENA 0.2.4

#### Features

  * `center.align.to.origin` defaults to TRUE
  * Layering in ena.plot.networks controlled by parameter `layers`, defaults to nodes on top with `c("edges", "nodes")`
  * Position nodes on a unit circle (either on line from origin or equally spaced) or optimized (still the default)
  * Added export of Microsoft Word document from `ena.writeup()` => `ena.writeup(set, type = 'file')`
  
#### Bugs
  
  * Fixed typos in `ena.writeup()`

## rENA 0.2.3

#### Bugs
  * Removed Vignettes

#### Feature 
  * Added option `center.align.to.origin` to `ena.make.set()`, when TRUE centers zero points to the origin (default: FALSE)

## rENA 0.2.2.0

#### Bugs
  * Removed outline from plotted nodes in networks
  
#### Features
  * Weighting function now applied at the line level, not at the unit level

## rENA 0.2.1.2

#### Bugs
  * Bug fix in window accumulation

## rENA 0.2.1.1

#### Bugs
  * Removing test checking for output
  * Including 'webshot' as Suggests to fix for issues on CRAN

## rENA 0.2.1.0

#### Features
  * Projections use the centering vector of a provided rotation set. See `ena.make.set()`
  * Faster correlation function: `ena_correlation()`

## rENA 0.2.0.1
  * Fix for updated r-devel to 4.0.0

## rENA 0.2.0.0

#### Features

  * New `ena()` function for easier model generation
  * Updated default model object returned by all methods.  See help for `ena()`
  * Custom S3 methods for removing meta data from data.frames on the ena model.
      - e.g. as.matrix(set$line.weights)

#### Bugs

  * Fixed bug in accumulation code for forward windows
