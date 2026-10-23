# ENA.jl

Epistemic Network Analysis in Julia: accumulate coded data into networks and
fit ENA models — SVD, means and generalized (GMR) rotations, node positions,
ordered (ONA) and self-connection models from TMA.jl — with the same results
as [rENA](https://gitlab.com/epistemic-analytics/qe-packages/rENA) (R), qe-ena
(Python) and rena-wasm (JavaScript). The numerics are libena, the C++ layer
those packages share (`inst/include/libena` in this repository), built on
[libqe](https://github.com/epistemic-analytics/libqe)'s generic numerics
(LibQE.jl); accumulation is TMA.jl's. Built with
[CxxWrap.jl](https://github.com/JuliaInterop/CxxWrap.jl).

## Install

ENA.jl is in the QE package registry:

```julia
using Pkg
Pkg.Registry.add(RegistrySpec(url = "https://gitlab.com/epistemic-analytics/qe-packages/cranqe.git#julia"))
Pkg.add("ENA")
```

Its C++ library comes prebuilt from **ENA_jll** (built by cranqe with
BinaryBuilder for Linux x86_64 / aarch64 and Windows x86_64; Julia 1.11 and
CxxWrap 0.15), so `Pkg.add("ENA")` needs no compiler there. Elsewhere (macOS
for now) ENA.jl loads a local CMake build from `julia/lib/libena_julia`, which
needs a C++17 compiler, CMake and [Armadillo](https://arma.sourceforge.net/).

### Development

ENA.jl pins `ENA_jll` to its own version, which is registered only at
release, so a checkout develops a local stand-in for it (`dev/local_jll.jl`,
once; `dev/ENA_jll/` is git-ignored) that points at the CMake build in `lib/`.
Run it before CMake: it also installs CxxWrap, which CMake asks for.

```sh
sh scripts/sync-headers.sh            # repo root: libena + libqe (from Conan) → julia/include
cd julia
julia --project=. dev/local_jll.jl
cmake -B build -DCMAKE_BUILD_TYPE=Release .
cmake --build build && cmake --install build      # → julia/lib/libena_julia
julia --project=. -e 'using Pkg; Pkg.test()'
```

ENA.jl depends on TMA.jl and LibQE.jl, which come from the QE registry (add
it as in Install). To work against local checkouts of them instead, develop
their `julia/` directories (and their `dev/<Name>_jll` stand-ins) into one
environment and test from there:

```julia
using Pkg
Pkg.activate(mktempdir())
Pkg.develop([PackageSpec(path = p) for p in [
    "../libqe/julia/dev/LibQE_jll", "../libqe/julia",    # paths from this repo's parent
    "../tma/julia/dev/TMA_jll", "../tma/julia",
    "julia/dev/ENA_jll", "julia"]])
Pkg.test("ENA")
```

Outside a checkout (a registered install contains `julia/` only), CMake takes
libena and libqe from their Conan packages instead:

```sh
conan remote add qe-libs https://gitlab.com/api/v4/projects/22522458/packages/conan
conan install --requires=libena/<version> -r qe-libs -g CMakeDeps -g CMakeToolchain \
      --output-folder=build/conan
cmake -B build -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_TOOLCHAIN_FILE=build/conan/conan_toolchain.cmake .
```

## Quick start

`data` is any [Tables.jl](https://github.com/JuliaData/Tables.jl) table — a
`DataFrame`, a CSV.jl file, or a `NamedTuple` of columns — with one row per
line of talk: who said it, which conversation it belongs to, and 0/1 codes.

```julia
using ENA, CSV

rs = CSV.File("rs.data.csv")      # rENA's RS.data (inst/extdata/rs.data.csv)
codes = [:Data, Symbol("Technical Constraints"), Symbol("Performance Parameters"),
         Symbol("Client and Consultant Requests"), Symbol("Design Reasoning"), :Collaboration]

# 1. Accumulate: each unit's co-occurrence network, a moving stanza window of
#    4 lines within each conversation (= rENA's ena.accumulate.data).
acc = ENA.accumulate(rs, [:UserName, :Condition], [:ActivityNumber, :GroupName], codes;
                     window_size = 4)
acc.connection_counts            # 48 units × 15 connections
acc.unit_labels[1]               # "steven z::FirstGame"

# 2. Fit (= rENA's ena.make.set): sphere-normalize, center, rotate, place nodes.
m = ENA.fit(acc)                                                     # SVD
m = ENA.fit(acc; rotation = MeansRotation(:Condition, "FirstGame", "SecondGame"))
m = ENA.fit(acc; rotation = GeneralizedRotation(:Condition))         # GMR
m = ENA.fit(acc; rotation = GeneralizedRotation([:Condition, Symbol("CONFIDENCE.Pre")]))

m.points        # units × 2: each unit's position
m.nodes         # codes × 2: the codes' positions
m.centroids     # units × 2: each network's centroid (fits m.points)
m.variance      # each dimension's share of the variance
m.rotation_names[1:2]            # ["MR1", "SVD2"], ["GMR1", "SVD2"], …

# Post-fit: nodes on a circle in the plane of dimensions 1 and 2.
m2 = move_nodes_to_unit_circle(m; dims = (1, 2), mode = :equal)
```

Group units for a means rotation by a `meta` column (one value per unit: the
unit's first line), `Bool` vectors over the units, or unit labels. A
generalized rotation's target is a `meta` column (numeric → regression, else
categorical), vectors of `Symbol`s add covariates (with pairwise interactions,
`interactions = true`), `y = …` gives a second GMR dimension, and
`select_2_groups = (a, b)` fits a categorical target on two of its groups.

### Ordered (ONA) and self-connection models

`ENA.fit` also models TMA.jl's accumulations (as rENA's `model()` models tma's):
ordered networks get ONA's directed node positions, and unordered networks
with self-connection columns (A & A, A & B, B & B, …) are placed by their
adjacency key. `self_weight` (default 2, as rENA) is a self-connection's
weight in its code's node weight.

```julia
using TMA
tensor = context_tensor(rs; default_window = 4)
ona = TMA.accumulate(rs, [:UserName, :Condition], [:ActivityNumber, :GroupName], codes;
                     tensor, ordered = true, split_by = [:ActivityNumber, :GroupName])
m = ENA.fit(ona)                 # m.ordered == true; 36 directed connections
```

## API

The pipeline:

| Function | Returns |
|----------|---------|
| `ENA.accumulate(data, units, conversations, codes; window_size=4, window_forward=0, binary=true)` | `ENAAccumulation`: `connection_counts`, `row_connection_counts`, `unit_labels`, `codes`, `connection_names`, `adjacency_key`, `meta` |
| `ENA.fit(accumulation; dims=2, norm=:sphere, rotation=:svd, self_weight=2.0)` | `ENAModel`: `points`, `nodes`, `centroids`, `rotation` (and `full_rotation`, `rotation_names`, `eigenvalues`), `line_weights`, `points_for_projection`, `variance`, `center_vec`, `weights`, … |
| `ENA.fit(data, units, conversations, codes; window_size=4, …)` | accumulate, then fit |
| `MeansRotation(group1, group2)`, `MeansRotation(column, value1, value2)` | a means rotation for `fit` |
| `GeneralizedRotation(x; y, select_2_groups, interactions=true, n_lambda=50, k_folds=5, lasso_eps=0.01)` | a GMR for `fit` |
| `move_nodes_to_unit_circle(model; dims=(1, 2), mode=:equal)` | the model with its nodes on a circle (post-fit) |

`accumulate` and `fit` are not exported: call them `ENA.accumulate` /
`ENA.fit`.

The libena kernels the pipeline uses, for working with matrices directly:

| Function | Returns |
|----------|---------|
| `ena_svd(points)` | `(rotation, eigenvalues, column_names)`; eigenvalues are `sdev^2`, as `prcomp` |
| `deflate(data, axis)` | `data` with `axis` projected out |
| `orthogonal_svd(data, weights, labels)` | rotation with the named axes orthonormalized (QR), rest from SVD |
| `complete_rotation(data, named_axes, labels)` | rotation keeping the named axes verbatim, rest from SVD |
| `means_rotation(data, group_pairs)` | means rotation (`MR1`, …); pairs of 0-based `Int32` row indices |
| `generalized_means_rotation(V, x_model, x_target, x1_cols, …)` | GMR (`GMR1`, `GMR2`/`SVD2`, …) with Lasso covariate adjustment |
| `node_positions(adj_mats, t, num_dims)` | `(nodes, centroids, weights, points)` |
| `directed_node_positions(line_weights, points, num_dims; self_weight=2.0)` | the same, for directed (ordered) networks |
| `directed_node_positions_combine_pairs(line_weights, points, num_dims; self_weight=2.0)` | directed, ground + response rows combined |
| `node_weights_by_key(line_weights, from, to, n_codes; self_weight=2.0)`, `node_positions_by_key(…)`, `node_centroids_by_key(…)` | node weights / positions / centroids for any layout of connection columns (column `k` connects codes `from[k]`, `to[k]`, 1-based) |
| `move_nodes_to_unit_circle(line_weights, nodes; dims=(1, 2), mode=:equal, directed=false, self_weight=2.0)` | `(nodes, centroids)`: a fitted model's nodes moved onto a circle in the plane of `dims` (1-based), `:equal`ly spaced or `:radial`ly, and the centroids for them (post-fit, as rENA's `move_nodes_to_unit_circle*()`) |
| `move_nodes_to_unit_circle_by_key(line_weights, nodes, from, to; dims, mode, self_weight)` | the same for any layout of connection columns |
| `ena_correlation(points, centroids; conf_level=0.95)` | `n_dims × 3`: `[r, ci_lower, ci_upper]` |
| `ccd_window(conversations; max_window=20, min_overlap=10)` | `(window_size, peak_lag, lag, frob, …)` |

Docstrings (`?ENA.fit`, `?ena_svd`) give the full argument lists.
