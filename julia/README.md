# ENA.jl

Julia bindings for libena, the Epistemic Network Analysis C++ layer shared by
[rENA](https://gitlab.com/epistemic-analytics/qe-packages/rENA) (R), qe-ena
(Python) and rena-wasm (JavaScript): rotations, node positions, ENA
correlations and CCD window estimation. The C++ lives in this repository
(`inst/include/libena`) and builds on [libqe](https://github.com/epistemic-analytics/libqe)'s
generic numerics.

These functions moved here from LibQE.jl, which keeps them only until libqe
0.2.0. Built with [CxxWrap.jl](https://github.com/JuliaInterop/CxxWrap.jl);
results are plain NamedTuples, so ENA.jl loads alongside LibQE.jl.

## Install

ENA.jl is in the QE package registry:

```julia
using Pkg
Pkg.Registry.add(RegistrySpec(url = "https://gitlab.com/epistemic-analytics/qe-packages/cranqe.git#julia"))
Pkg.add("ENA")
```

Its C++ library (`lib/libena_julia`) is built with CMake; it needs a C++17
compiler, CMake, [Armadillo](https://arma.sourceforge.net/) and CxxWrap 0.15
(Julia 1.11; CxxWrap 0.15 has no Julia 1.13 binary).

From an rENA checkout, vendor the headers first:

```sh
sh scripts/sync-headers.sh            # repo root: libena + libqe (from Conan) → julia/include
cd julia
julia --project=. -e 'using Pkg; Pkg.instantiate()'
cmake -B build -DCMAKE_BUILD_TYPE=Release .
cmake --build build && cmake --install build      # → julia/lib/libena_julia
julia --project=. -e 'using Pkg; Pkg.test()'
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

```julia
using ENA

pts = randn(20, 4)
pts .-= sum(pts, dims = 1) ./ size(pts, 1)   # center first, as rENA does

r = ena_svd(pts)              # (rotation, eigenvalues, column_names)
r.column_names                # ["SVD1", "SVD2", "SVD3", "SVD4"]

m = means_rotation(pts, [(Int32[0, 1, 2], Int32[3, 4, 5])])   # 0-based rows
m.column_names[1]             # "MR1"

np = node_positions(abs.(randn(20, 6)), pts * r.rotation[:, 1:2], 2)
size(np.nodes)                # (4, 2): 4 codes → choose_two(4) = 6 connections

ccd_window([rand(0:1, 30, 3) .* 1.0 for _ in 1:4]; max_window = 10)
```

## API

| Function | Returns |
|----------|---------|
| `ena_svd(points)` | `(rotation, eigenvalues, column_names)`; eigenvalues are `sdev^2`, as `prcomp` |
| `deflate(data, axis)` | `data` with `axis` projected out |
| `orthogonal_svd(data, weights, labels)` | rotation with the named axes orthonormalized (QR), rest from SVD |
| `complete_rotation(data, named_axes, labels)` | rotation keeping the named axes verbatim, rest from SVD |
| `means_rotation(data, group_pairs)` | means rotation (`MR1`, …); pairs of 0-based `Int32` row indices |
| `generalized_means_rotation(V, x_model, x_target, x1_cols, …)` | GMR (`GMR1`, `GMR2`/`SVD2`, …) with Lasso covariate adjustment |
| `node_positions(adj_mats, t, num_dims)` | `(nodes, centroids, weights, points)` |
| `directed_node_positions(line_weights, points, num_dims)` | the same, for directed (ordered) networks |
| `directed_node_positions_combine_pairs(line_weights, points, num_dims)` | directed, ground + response rows combined |
| `ena_correlation(points, centroids; conf_level=0.95)` | `n_dims × 3`: `[r, ci_lower, ci_upper]` |
| `ccd_window(conversations; max_window=20, min_overlap=10)` | `(window_size, peak_lag, lag, frob, …)` |

Docstrings (`?ena_svd`) give the full argument lists.
