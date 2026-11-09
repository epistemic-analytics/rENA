## rENA 0.4.18 (development version)

## rENA 0.4.17

Released with qe-ena 0.1.11 (tag `python/v0.1.11`) and rena-wasm 0.1.18 (`wasm/v0.1.18`). libena's C++ is unchanged since 0.4.16, so there is no libena release this cycle. ENA.jl's matching fix ships with ENA.jl 0.1.5 (tag `julia/v0.1.5`), released on its own once its ENA_jll build is available.

- `model()`, `center()` and `optimize()` follow `ena.make.set(center.align.to.origin = TRUE)`, the webtool's rule, for units whose network is empty: with `exclude_zero_networks = TRUE`, now `model()`'s default for every kind of set, an all-zero unit stays at the origin. `center()` centers the other units on their own mean and leaves the empty ones at zero (before, it subtracted that mean from every unit, so an empty network landed at minus the mean, as far from the centroid as any real unit). `optimize()` gains `exclude_zero_networks` (default `TRUE`): empty units are left out of the node fit and get zero centroids, and for unordered sets the nodes and centroids are shifted so the fitted units' mean centroid is at the origin, as the legacy solver does; ordered sets are fit on the other units without that shift, as ONA 0.1.1 did. On RS.data with units including GroupName (two empty networks of 96), the piped model now matches `ena.make.set()` to 1e-10 in points, nodes, centroids and eigenvalues; before, points differed by up to 0.5 and nodes by up to 1.0. Ordered models change the same way: an empty unit's point moves from minus the mean to the origin and the rotation from dimension 3 on, matching ONA 0.1.1 (`ona`'s parity fixture). Sets without empty units are unchanged. `exclude_zero_networks = FALSE` reproduces `center.align.to.origin = FALSE`.
- rena-wasm, qe-ena and ENA.jl follow the same zero-network rule as `model()` above, so all four agree with `ena.make.set(center.align.to.origin = TRUE)` and ONA 0.1.1 on data with units whose network is empty: such a unit stays at the origin, is left out of the centering mean and the node fit, and has a zero centroid; unordered models shift the nodes and centroids so the fitted units' mean centroid is at the origin, ordered models are fit on the other units without that shift. rena-wasm: `fit()`'s `centerAlignToOrigin` (default `true`) now applies to ordered (ONA) models too, which used to shift an empty unit to minus the mean as the old `ona::model()` did, and the node fit leaves empty units out; `centerAlignToOrigin: false` is still `center.align.to.origin = FALSE` for every kind of model. The `rs_zero` ONA fixtures (`wasm/test/fixtures/ona-model-rs.json`) were refrozen from this rule with `wasm/test/fixtures/ona-fixtures-rs.R`, which now runs against the rENA and ona checkouts. qe-ena and ENA.jl already centered on the non-empty units; their node fit now leaves the empty units out as well (zero centroids, the unordered shift). New parity tests against `model()` on RS.data accumulated by UserName, Condition and GroupName (two empty units unordered, one ordered; `python/tests/fixtures/zero-networks.R`, the JSON shared with `julia/test/fixtures/`) match points, nodes, centroids, eigenvalues and variance to 1e-10. Models without empty units are unchanged in all three.
- rena-wasm requires `@qe-libs/libqe-wasm` >= 0.2.5 (was >= 0.1.6, and its lockfile still pinned 0.1.6), so it always loads the libqe-wasm that is built without dynamic execution (0.2.4 and later), as 0.1.17's CSP-safe loading needs.
- rena-wasm 0.1.17 (released on its own, tag `wasm/v0.1.17`) is linked with `-sDYNAMIC_EXECUTION=0`, so libena's Embind glue no longer builds function invokers with `new Function`. It loads under Cloudflare Workers and any Content Security Policy without `unsafe-eval` (the ENA MCP server's Worker build needs this, together with libqe-wasm 0.2.4). Results are unchanged. R, qe-ena, ENA.jl and the C++ are unchanged.

## rENA 0.4.16

Released with qe-ena 0.1.10 (tag `python/v0.1.10`), rena-wasm 0.1.16 (`wasm/v0.1.16`) and libena 0.4.16 (`conan/v0.4.16`). rena-wasm's README examples run in the browser on qe-libs.org, and libena's Conan docs gain a main page.

- ENA.jl 0.1.4 (released on its own, tag `julia/v0.1.4`) fits ENA models end to end, as rENA and qe-ena do (before, it had only the libena kernels). `ENA.accumulate(data, units, conversations, codes; window_size, window_forward, binary)` is the stanza-window accumulation (TMA.jl's `accumulate_stanza`) on any Tables.jl table, returning an `ENAAccumulation`. `ENA.fit(accumulation; dims, norm, rotation, self_weight)` returns an `ENAModel` (points, nodes, centroids, rotation, line weights, variance, ...): sphere norm and centering from LibQE.jl, rotation by SVD (default), `MeansRotation` or `GeneralizedRotation` (target, covariates with interactions, `y`, `select_2_groups`) through libena's `ena_svd` / `means_rotation` / `generalized_means_rotation`, and libena's node positions. It also models TMA.jl's `TMA.accumulate` results: ordered networks with ONA's directed node positions, self-connection columns by their adjacency key. `move_nodes_to_unit_circle(model)` moves a fitted model's nodes, and the new kernel binding `move_nodes_to_unit_circle_by_key()` handles self-connection layouts. On RS.data the accumulation and the SVD, means and four generalized models match rENA's `ena.accumulate.data()` / `ena.make.set()` to 1e-10 (`julia/test/fixtures/ena-rs.R`), and models of tma accumulations match rENA's `model()` (`julia/test/fixtures/tma-models.json`). ENA.jl now depends on TMA.jl (>= 0.1.6, for `TMAAccumulation`), LibQE.jl and Tables.jl.
- ENA.jl 0.1.3 (released on its own, tag `julia/v0.1.3`) loads its C++ library from **ENA_jll**, built by cranqe with BinaryBuilder for Linux (x86_64, aarch64) and Windows (x86_64), so `Pkg.add("ENA")` needs no compiler there; it pins `ENA_jll` to its own version (`=0.1.3`). Where ENA_jll has no build (macOS for now), ENA.jl loads a local CMake build from `julia/lib/` as before; in a checkout, `julia/dev/local_jll.jl` develops a stand-in ENA_jll pointing at that build (`julia/README.md`: Development). ENA.jl 0.1.3 also carries this cycle's libena changes above (`*_by_key`, `self_weight`).
- qe-ena models TMA accumulations, as rENA's `model()` models tma's in R: `ENA().fit()` accepts qe-tma's `TMAAccumulation` (`tma.accumulate()`), placing ordered networks with ONA's directed node positions and unordered networks with self-connection columns by their adjacency key; new `self_weight` (default 2, = R) and `ordered_` / `self_weight_` on the model, which `move_nodes_to_unit_circle()` follows. Matches rENA's `model()` (SVD) on tma's accumulation to ~1e-15 (`python/tests/fixtures/tma-models.R`). qe-tma no longer models (it imported qe-ena for node positions); qe-ena reads the accumulation's fields and does not require qe-tma. Standard ENA fits are unchanged.
- Requires libqe >= 0.2.1 (diagonal adjacency helpers) and tma >= 0.3.9 (`accumulate(self_connections)`); `scripts/sync-headers.sh` vendors libqe 0.2.1 and libtma 0.3.9, and the libena Conan recipe requires libqe >= 0.2.1.
- `ena.plot.network()` plots networks with self-connections (p(p+1)/2 weights from `accumulate(self_connections = TRUE)`, upper triangle with the diagonal). Each self weight is a filled circle on its node, as wide as an edge of the same weight and coloured the same way (positive/negative for subtractions); it counts once toward the node's size, and a node is never drawn smaller than its circle. Works on both backends; the qeviz backend needs qeviz with undirected self-connection support (sandbox/qeviz `feat/undirected-self-connections`). `namesToAdjacencyKey()` gains `diagonal` for the self-connection layout. Networks without self-connections plot as before.
- Unordered models can include self-connections: `accumulate(self_connections = TRUE)` (passed to `tma::accumulate()`) adds each code's self-connection as a connection column (A & A, A & B, B & B, ...), and `model()` takes it through normalization, rotation (SVD, means and generalized) and node positions, where it counts `self_weight` times (default 2), as in ordered models. Unordered node positions now come from libena's key-driven solver using the set's adjacency key -- identical to before for the usual choose(n, 2) columns -- and `rotate()` keeps the adjacency key and centering vector it used to drop. Ordered models are unchanged (they always carry the diagonal and keep `directed_node_positions()`). rena-wasm: `accumulate()` / `fit()` take `selfConnections`; its unordered nodes, custom-rotation centroids, code mask and unit-circle move follow the key. Window tuning and PRIA keep the standard layout. Results match between R and rena-wasm (rs.data: line weights, points and nodes to ~1e-14).
- Layout-agnostic node optimization in libena: `node_weights_by_key()`, `node_positions_by_key()`, `node_centroids_by_key()` and `move_nodes_to_unit_circle_by_key()` take a column key (which two codes each connection column connects) instead of assuming a layout. One rule: every connection counts toward each code it connects, a self-connection toward its code `self_weight` times (default 2), each unit's weights L1-normalised. With the undirected key it equals the undirected solver; with the ordered key, `directed_node_positions()` at the same `self_weight`; it also handles undirected networks with self-connection columns (A & A, A & B, B & B, ...), where on symmetric data it equals ONA's weighting. Key helpers: `undirected_connection_key(n, diagonal)` / `directed_connection_key(n)`. R: `node_positions_by_key()` / `node_centroids_by_key()` (from an adjacency key and the codes); qe-ena, rena-wasm and ENA.jl expose the same functions. Uses libqe's `connection_indices(n, row, diagonal)`.
- Ordered (ONA) node optimization counts a self-connection (the diagonal, ground i -> response i) twice in its code's node weight again: a node's weight is the sum of its column plus the sum of its row of the unit's adjacency matrix (in + out), as Zhiqiang Cai defined it in directedENA (2021-10-29). libena had counted it once since May 2026, on the premise that the diagonal was always zero, which it is not. Node positions and centroids of ordered models change (on RS.data, window 4, nodes move ~13% of their spread on average); points, rotation and variance do not. New `self_weight` (default 2; 1 = the once-counted rule) on `model()`, `optimize()`, `directed_node_positions()` and `directed_node_positions_with_ground_response_added()`, recorded as `set$rotation$self.weight` and used by `move_nodes_to_unit_circle()`; also in libena (`directed_node_weights`, `directed_node_positions`, `node_centroids`, `move_nodes_to_unit_circle`), rena-wasm (`fit({ selfWeight })`, `rotation.selfWeight`), qe-ena and ENA.jl.
- `ena.plot.network(scale.weights = TRUE)` no longer fails with `invalid hsv color`. The `thickness`, `saturation` and `opacity` ranges were still in unscaled units after the network was normalised to max |w| = 1, so colours and opacities went outside [0, 1] (almost any network whose largest weight is under 1 failed, subtraction networks included). The ranges are now scaled with the network, and saturation and opacity are clamped to [0, 1]. Colour and opacity now match `scale.weights = FALSE`, and edge widths fall within `scale.range` times the plot multiplier. Before, the edges of a FirstGame - SecondGame network on `RS.data` would have been up to 44.5 px wide next to 3-10 px nodes. `scale.weights = FALSE` is unchanged.

## rENA 0.4.15

- Requires tma >= 0.3.8 (`scripts/sync-headers.sh` vendors libtma 0.3.8), which keeps missed co-occurrences and self-connections through accumulation. Sets from `accumulate()` now carry `self.connection.counts` -- each code's ground count times its response count (the ordered network's diagonal, which unordered networks fold away) -- and, with `misses`, `miss.counts` and `self.miss.counts` (the code in the ground, absent from the response), plus their per-line tables in `model`. They are kept alongside the connection counts and do not change the model. Tests check that they survive `model()` and leave the fitted model unchanged.
- `accumulate()` gains `misses` (default `TRUE`), passed to `tma::accumulate()`; `misses = FALSE` skips them. Before, rENA always got tma's default and could not turn them off.
- rena-wasm: accumulation goes through libtma's `accumulate_unit_networks()` (one call per unit and context: fold, per-line weight model, unit sum, self-connection diagonal) and `weight_rows()` for the per-line `rowConnectionCounts`, so the JS no longer finalises rows itself. Results are unchanged (identical on rs.data; `sqrt` within 1e-13). `accumulate()` and `fit()` gain `selfConnectionCounts` (units x codes) and, with `misses` (default `true`), `missCounts` and `selfMissCounts` -- equal to R's `self.connection.counts`, `miss.counts` and `self.miss.counts`. The new libtma functions (and `accumulate_tensor_unit_misses`) are now reachable through `loadENA()`.
- qe-ena: `ENA.fit()`'s default SVD rotation reports `rotation_eigenvalues_` as sdev^2 (= R's `rotation$eigenvalues` and rena-wasm), not raw singular values. It now uses libena's `ena_svd` instead of `numpy.linalg.svd`, keeping min(units, connections) axes.

## rENA 0.4.14

- `move_nodes_to_unit_circle()` and `move_nodes_to_unit_circle_with_equal_space()` run in libena (`inst/include/libena/positions.hpp`: `unit_circle_nodes()`, `node_centroids()`, `move_nodes_to_unit_circle()`; the node weighting of `node_positions()` / `directed_node_positions()` is factored out into `node_weights()` / `directed_node_weights()` for it, with identical results), so every binding shares one implementation. Same signatures and, for unordered sets, the same results. They now also work for ordered sets: the centroids use the directed weighting the fit uses (the R code read only the i < j connections, so its ordered centroids were wrong unless the networks were symmetric). Centroids come from `set$line.weights`, as the fit's do; the input set is never modified, the columns keep their classes (the centroids' used to lose `ena.dimension`), and an equally spaced move of a set whose nodes are all zero in the plane leaves it unchanged instead of failing. Documented, with examples.
- The other bindings get the same post-fit call: qe-ena `ENA.move_nodes_to_unit_circle(dims=(0, 1), mode="equal")` (returns a moved copy) and `ena.libena.move_nodes_to_unit_circle()`; rena-wasm `moveNodesToUnitCircle(model, { dims: [0, 1], mode: 'equal' })` (returns a moved copy) and `qe.move_nodes_to_unit_circle`; ENA.jl `move_nodes_to_unit_circle(line_weights, nodes; dims=(1, 2), mode=:equal, directed=false)`. Fitting is unchanged.
- Works with libqe 0.2.0, which drops its copies of the ENA and accumulation code (rENA no longer uses them). qe-ena 0.1.7 allows `qe-lib<0.3`; rena-wasm allows `@qe-libs/libqe-wasm` 0.2 (its libqe-wasm parity tests skip the functions 0.2 removed).
- CI and `scripts/sync-headers.sh` take tma and libtma from their releases; the fallbacks to tma's `develop` branch are gone.

## rENA 0.4.13

#### Bug Fixes & Improvements

  * rENA is a compiled package again. The ENA model code (rotations,
    generalized means rotation, node positions, `ena_correlation`,
    `ccd_window`) moved out of libqe into rENA as the header-only C++ layer
    libena (`inst/include/libena/`, wrapped in `src/libena_rcpp.cpp`), so
    libqe can return to generic numerics. Results are unchanged: the code and
    its tests moved verbatim. Installing from source now needs a C++
    toolchain (Rtools on Windows); qe-libs.org serves binaries for Windows
    and macOS. Requires libqe >= 0.1.9.
  * The other bindings compile libena themselves instead of calling libqe's
    copies: qe-ena gets the `ena._libena` extension (`ena.libena`; wheels
    for Linux, macOS and Windows), rena-wasm builds `dist/libena.wasm`, and
    the new Julia package ENA.jl (`julia/`) replaces LibQE.jl's ENA
    functions — adding `ccd_window` and fixing `ena_correlation` (wrong
    result shape) and `directed_node_positions_combine_pairs` (always
    errored) on the way. libena is also published as a Conan package.
  * Accumulation comes from tma instead of libqe: the R stanza-window
    wrappers call `tma::accumulate_stanza` / `row_connections` /
    `rolling_window_sum` (requires tma >= 0.3.6), and qe-ena and rena-wasm
    compile tma's libtma accumulation into their own modules (identical
    results).

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
