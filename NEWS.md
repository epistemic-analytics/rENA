## rENA 0.4.12

#### Bug Fixes & Improvements

  * rena-wasm 0.1.11: `model.variance` is each dimension's share of the total
    variance whatever `dims` a fit keeps, as R's `set$model$variance` is
    regardless of `dimensions`. It previously divided by the variance of only
    the returned dimensions, so a default 2-dimension fit always reported
    shares summing to 100% (58.1% / 41.9% instead of 31.9% / 23.0% on
    RS.data). Fits that keep every dimension (the webtool's) are unchanged.

## rENA 0.4.11

#### Bug Fixes & Improvements

  * Requires libqe >= 0.1.6; rena-wasm 0.1.10 requires `@qe-libs/libqe-wasm`
    ^0.1.6.

  * GMR (`ena.rotate.by.generalized`, and rena-wasm's `'generalized'`
    rotation) is orthonormal on models with a masked (all-zero) connection,
    through libqe 0.1.6's `complete_rotation` fix. One of the SVD axes used to
    nearly duplicate GMR1, skewing those axes and the variance shares (GMR1
    23.7% instead of 29.9% on RS.data with one connection masked). Unmasked
    models are unchanged.

  * rena-wasm 0.1.10: a model projected into another model's space
    (`rotationSet`) reports each dimension's share of the total variance, as
    `ena.make.set(rotation.set = )` does with the full rotation matrix. It
    previously divided by the variance of only the dimensions the rotation
    set carries (the webtool stores 6), which inflated the percentages
    (e.g. 41.5% instead of 28.8% on dimension 1).

## rENA 0.4.10

#### New Features

  * `skip_sphere_norm()`, the piped counterpart of `sphere_norm()` for
    `fun_skip_sphere_norm`: every network is divided by the length of the
    longest one instead of being scaled to length 1. Pass it as `normalize` to
    `model()` (or `ona::model()`, which hands it on) to build a model without
    sphere normalization, including ordered (ONA) models.

#### Bug Fixes & Improvements

  * rena-wasm 0.1.9 (`@qe-libs/rena-wasm`) adds the remaining window and
    rotation options of the R pipeline, each matching R on RS.data:
    * `window: Infinity` = `window.size.back = Inf`.
    * Time-based windows: a tensor's `timesCol` (parsed like rENA.api's
      `parse_date`), `timeUnit` and `timesEndCol` match `tma::accumulate()`
      with a time column.
    * Flexible horizons: `horizons: { by, rules }` builds each unit's
      contexts as `tma::contexts()` does with HOO rules, split on the horizon
      columns.
    * Custom rotations: `rotationSet` projects into another model's space, as
      `ena.make.set(rotation.set = )` does.
    * `sphereNorm: false` (= `norm.by = fun_skip_sphere_norm`; for ordered
      models, `ona::model(normalize = skip_sphere_norm)`) and, for unordered
      models, `centerAlignToOrigin: false` (= `center.align.to.origin = FALSE`).
  * rena-wasm 0.1.9: a time of `0` in a numeric time column (`timesCol`) is
    now read as 0; it was replaced by the row's position in its conversation.

## rENA 0.4.9

#### New Features

  * qeviz plotting backend. `ena.plot(backend = "qeviz")`, or
    `options(rENA.plot.backend = "qeviz")`, draws plots with the qeviz package
    (>= 0.5.0, from https://cran.qe-libs.org; Suggests) instead of plotly.
    Existing plotting code works unchanged: `ena.plot.network()`,
    `ena.plot.points()`, `ena.plot.group()`, `ena.plotter()`,
    `ena.plot.subtraction()` and the pipe API (`add_network()`, `add_points()`,
    `add_group()`, `with_means()`, `check_range()`, `show()`) add qeviz layers,
    and `$plot` is a qeviz htmlwidget. Plotly stays the default.
    * Widths and colours follow qeviz's model-wide scaling, so separate plots
      of one model are comparable. `thickness`, `opacity`, `saturation`,
      `scale.range` and `node.size` are ignored, with a warning once per
      session.
    * `ena.plotter()` multipliers become each plot's magnification, labelled
      "(scaled Nx)", rather than multiplying the weights.
    * Means drawn with `ena.plot.group()` keep their own confidence interval
      and outlier interval.
    * Not available on the qeviz backend: trajectories and movies
      (`ena.plot.trajectory()`, `add_trajectory()`, `ena.plot.movie()`,
      `with_trajectory()` warn and leave the plot unchanged), dashed edges,
      label offsets, legends, and `scale.to = list(x =, y =)`.

#### Bug Fixes & Improvements

  * `ena.plot.interactive()`, `ena.export.html()`, `enaInteractiveOutput()` and
    `renderEnaInteractive()` now wrap qeviz (>= 0.5.0) instead of a bundled
    copy of qeviz 0.1.0. Same names and arguments. Means and confidence
    intervals are now drawn for the groups shown (previously no means were
    drawn); `outlier` defaults to `FALSE`; `iqr_factor` is deprecated (always
    1.5 IQR). The bundled `inst/htmlwidgets/` widget is removed.
  * rena-wasm 0.1.8 (`@qe-libs/rena-wasm`): `fit()`, `accumulate()`,
    `tuneWindowSize()` and `pria()` take `unitsUsed`, the unit keys to model
    (= `units.used` in `ena.accumulate.data()`). Other units' rows stay in the
    data as context for the modeled units' windows, but those units are not
    modeled: they get no network and play no part in normalization, centring
    or rotation. Results match `ena.accumulate.data(units.used = ...)`.

## rENA 0.4.8

#### Bug Fixes & Improvements

  * `model()` now passes `rotate_params` to the rotation function as its
    `params` argument. It previously flattened lists with more than one
    element, so the two group vectors of a means rotation failed with
    "$ operator is invalid for atomic vectors", and a single parameter such as
    `list(x_var = "GameHalf")` was silently ignored. This also fixes
    `ona::model(rotate.using = "mean", rotation.params = list(g1, g2))`. The
    nested form `list(params = ...)` still works.
  * rena-wasm 0.1.7 (`@qe-libs/rena-wasm`): ordered (ONA) models now match
    `ona::model()`, the ONA standard. Node positions use directed
    least-squares positions, units with no connections are left out of the
    centring mean but shifted by it, and points and nodes are centred on the
    origin. This changes the node positions (and, when a dataset has units
    with no connections, the points) of ONA models built with rena-wasm, such
    as in the webtool. Unordered (ENA) models are unchanged.
  * rena-wasm 0.1.7: ordered models' `connectionNames` and
    `rotation.adjacencyKey` now list all n² directed connections in network
    column order, named as R names them (column `j*n + i` is
    `"codes[i] & codes[j]"`, ground `codes[i]` → response `codes[j]`).
    Previously they held the n(n-1)/2 unordered pairs.

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
