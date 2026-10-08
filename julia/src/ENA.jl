"""
    ENA

Julia bindings for libena — the Epistemic Network Analysis C++ layer shared by
rENA (R), qe-ena (Python) and rena-wasm (JavaScript): rotations (SVD, means,
generalized means), least-squares node positions, ENA correlations and CCD
window estimation.

The C++ lives in the rENA repository (`inst/include/libena`) and builds on
libqe's generic numerics.  These functions moved here from LibQE.jl (libqe's
phase 4a split) with the same signatures and results.

All functions accept standard Julia `Matrix{Float64}` / `Vector{Float64}`
arguments.  Matrix inputs are zero-copy (Julia and Armadillo are both
column-major); results are copied out once.

## Build

Build the C++ shared library before loading this package (see README.md):

```sh
sh ../scripts/sync-headers.sh      # from julia/ in an rENA checkout
cmake -B build -DCMAKE_BUILD_TYPE=Release .
cmake --build build
cmake --install build              # copies libena_julia → julia/lib/
```
"""
# CxxWrap loads a native shared library at module init time; precompilation
# of the method table is not safe across different library builds.
__precompile__(false)

module ENA

using CxxWrap

# ── Public API ────────────────────────────────────────────────────────────────
export
    # Correlation and node positions
    ena_correlation, node_positions, directed_node_positions,
    directed_node_positions_combine_pairs,
    # Rotation
    ena_svd, deflate, orthogonal_svd, complete_rotation,
    means_rotation, generalized_means_rotation,
    # Window estimation
    ccd_window

# ── Load shared library ───────────────────────────────────────────────────────
# The library built by CMake is installed into julia/lib/ (one level up from
# this file's julia/src/ directory).  cranqe runs the build step before
# invoking Pkg.test(); for local testing build it manually first (see above).
const _lib_dir  = joinpath(@__DIR__, "..", "lib")
const _lib_name = "libena_julia"

function _lib_path()
    for ext in ("", ".so", ".dylib", ".dll")
        p = joinpath(_lib_dir, _lib_name * ext)
        isfile(p) && return p
    end
    error("libena_julia shared library not found in $(_lib_dir). " *
          "Build it first: cd julia && cmake -B build -DCMAKE_BUILD_TYPE=Release . " *
          "&& cmake --build build && cmake --install build")
end

@wrapmodule(_lib_path)

function __init__()
    @initcxx
end

# ── StdVector converters ──────────────────────────────────────────────────────
# CxxWrap 0.15 exposes C++ std::vector<T> params as StdVector{T}, not Vector{T}.
# Julia does not auto-convert between the two, so we do it explicitly.

function _sv_i32(v::AbstractVector{<:Integer})
    sv = CxxWrap.StdLib.StdVector{Int32}()
    for x in v; push!(sv, Int32(x)); end
    sv
end

function _sv_str(v::AbstractVector{<:AbstractString})
    sv = CxxWrap.StdLib.StdVector{CxxWrap.StdLib.StdString}()
    for x in v; push!(sv, CxxWrap.StdLib.StdString(x)); end
    sv
end

# ── Result unpacking ──────────────────────────────────────────────────────────
# The C++ methods return plain tuples (libena/bind/cxxwrap.hpp): matrices as
# (column-major data, rows, cols).  StdVector does not implement AbstractArray,
# so collect() before reshape.

_mat(data, rows, cols) = reshape(collect(Float64, data), Int(rows), Int(cols))

# (nodes, r, c, centroids, r, c, weights, r, c, points, r, c)
_unpack_positions(t) = (
    nodes     = _mat(t[1],  t[2],  t[3]),
    centroids = _mat(t[4],  t[5],  t[6]),
    weights   = _mat(t[7],  t[8],  t[9]),
    points    = _mat(t[10], t[11], t[12]),
)

# (rotation, r, c, eigenvalues, column_names)
_unpack_rotation(t) = (
    rotation     = _mat(t[1], t[2], t[3]),
    eigenvalues  = collect(Float64, t[4]),
    column_names = String[String(s) for s in t[5]],
)

# ── Correlation and node positions ────────────────────────────────────────────

"""
    ena_correlation(points, centroids; conf_level=0.95) -> Matrix{Float64}

Pearson correlation with CI between ENA unit points and group centroids.
Returns an `n_dims × 3` matrix (one row per dimension) with columns
`[r, ci_lower, ci_upper]`.
"""
function ena_correlation(points::Matrix{Float64}, centroids::Matrix{Float64};
                          conf_level::Float64 = 0.95)
    pr, pc = size(points)
    cr, cc = size(centroids)
    # One row per dimension (LibQE.jl reshaped to n_units rows, which threw
    # whenever n_units != n_dims).
    n_dims = pc
    reshape(ena_correlation(vec(points), Int32(pr), Int32(pc),
                                vec(centroids), Int32(cr), Int32(cc),
                                conf_level), n_dims, 3)
end

"""
    node_positions(adj_mats, t, num_dims) -> NamedTuple

Least-squares node positions for undirected ENA.
Returns `(nodes, centroids, weights, points)` — each a `Matrix{Float64}`.
"""
function node_positions(adj_mats::Matrix{Float64}, t::Matrix{Float64},
                             num_dims::Integer)
    (all(isfinite, adj_mats) && all(isfinite, t)) ||
        throw(ArgumentError("node_positions: input matrices must not contain NaN or Inf — " *
                            "filter or impute rows with non-finite values before calling"))
    ar, ac = size(adj_mats)
    tr, tc = size(t)
    r = node_positions(vec(adj_mats), Int32(ar), Int32(ac),
                       vec(t),        Int32(tr), Int32(tc), Int32(num_dims))
    _unpack_positions(r)
end

"""
    directed_node_positions(line_weights, points, num_dims) -> NamedTuple

Least-squares node positions for directed ENA.
Returns `(nodes, centroids, weights, points)`.
"""
function directed_node_positions(line_weights::Matrix{Float64},
                                  points::Matrix{Float64}, num_dims::Integer)
    (all(isfinite, line_weights) && all(isfinite, points)) ||
        throw(ArgumentError("directed_node_positions: input matrices must not contain NaN or Inf — " *
                            "filter or impute rows with non-finite values before calling"))
    lr, lc = size(line_weights)
    pr, pc = size(points)
    r = directed_node_positions(vec(line_weights), Int32(lr), Int32(lc),
                                vec(points),       Int32(pr), Int32(pc),
                                Int32(num_dims))
    _unpack_positions(r)
end

"""
    directed_node_positions_combine_pairs(line_weights, points, num_dims) -> NamedTuple

Directed ENA node positions — ground and response rows averaged before the
least-squares solve (`combine_pairs = true`).
Returns `(nodes, centroids, weights, points)`.
"""
function directed_node_positions_combine_pairs(line_weights::Matrix{Float64},
                                                points::Matrix{Float64},
                                                num_dims::Integer)
    (all(isfinite, line_weights) && all(isfinite, points)) ||
        throw(ArgumentError("directed_node_positions_combine_pairs: input matrices must not contain NaN or Inf — " *
                            "filter or impute rows with non-finite values before calling"))
    lr, lc = size(line_weights)
    pr, pc = size(points)   # LibQE.jl read pr/pc without defining them
    r = directed_node_positions_combine_pairs(
            vec(line_weights), Int32(lr), Int32(lc),
            vec(points),       Int32(pr), Int32(pc),
            Int32(num_dims))
    _unpack_positions(r)
end

# ── Rotation ──────────────────────────────────────────────────────────────────

"""
    ena_svd(points) -> NamedTuple{(:rotation, :eigenvalues, :column_names)}

SVD rotation of ENA point space.
Returns `(rotation, eigenvalues, column_names)`.
"""
function ena_svd(points::Matrix{Float64})
    all(isfinite, points) ||
        throw(ArgumentError("ena_svd: input matrix must not contain NaN or Inf — " *
                            "filter or impute rows with non-finite values before calling"))
    rows, cols = size(points)
    _unpack_rotation(ena_svd(vec(points), Int32(rows), Int32(cols)))
end

"""
    deflate(data, axis) -> Matrix{Float64}

Project out the given unit `axis` from `data` (remove its variance).
"""
function deflate(data::Matrix{Float64}, axis::Vector{Float64})
    rows, cols = size(data)
    reshape(deflate(vec(data), Int32(rows), Int32(cols), axis), rows, cols)
end

"""
    orthogonal_svd(data, weights, labels) -> NamedTuple

Weighted SVD with orthogonalization against previously fixed axes.
`labels` names the resulting axes.
Returns `(rotation, eigenvalues, column_names)`.
"""
function orthogonal_svd(data::Matrix{Float64}, weights::Matrix{Float64},
                         labels::Vector{String})
    dr, dc = size(data)
    wr, wc = size(weights)
    _unpack_rotation(orthogonal_svd(vec(data),    Int32(dr), Int32(dc),
                                    vec(weights), Int32(wr), Int32(wc),
                                    _sv_str(labels)))
end

"""
    complete_rotation(data, named_axes, labels) -> NamedTuple

Fix the columns of `named_axes` as the first rotation axes, then fill the
remaining dimensions with SVD of the doubly-deflated space.
`labels` names the fixed axes (length must equal `size(named_axes, 2)`).
Returns `(rotation, eigenvalues, column_names)`.
"""
function complete_rotation(data::Matrix{Float64}, named_axes::Matrix{Float64},
                            labels::Vector{String})
    dr, dc = size(data)
    ar, ac = size(named_axes)
    _unpack_rotation(complete_rotation(vec(data),       Int32(dr), Int32(dc),
                                       vec(named_axes), Int32(ar), Int32(ac),
                                       _sv_str(labels)))
end

"""
    means_rotation(data, group_pairs) -> NamedTuple

Group-means rotation.

`group_pairs` is a `Vector` of `Tuple{Vector{Int32}, Vector{Int32}}` where
each tuple holds **0-based** row indices for group A and group B.

Returns `(rotation, eigenvalues, column_names)`.
"""
function means_rotation(data::Matrix{Float64},
                         group_pairs::Vector{<:Tuple{Vector{Int32},Vector{Int32}}})
    rows, cols = size(data)
    a_flat  = vcat([p[1] for p in group_pairs]...)
    b_flat  = vcat([p[2] for p in group_pairs]...)
    a_sizes = Int32[length(p[1]) for p in group_pairs]
    b_sizes = Int32[length(p[2]) for p in group_pairs]
    _unpack_rotation(means_rotation(vec(data), Int32(rows), Int32(cols),
                                    _sv_i32(a_flat), _sv_i32(a_sizes),
                                    _sv_i32(b_flat), _sv_i32(b_sizes)))
end

"""
    generalized_means_rotation(V, x_model, x_target, x1_cols, x_categorical,
                                x_n_groups, x_subset, has_y, y_model, y_target,
                                y1_cols, y_categorical, y_n_groups;
                                n_lambda=50, k_folds=5, lasso_eps=0.01) -> NamedTuple

Generalized Means Rotation (GMR) with Lasso-based covariate adjustment.

Mirrors rENA's `ena.rotate.by.generalized()`. The x axis is the direction in
ENA space most explained by `x_target` after controlling for covariates via
Lasso (coordinate-descent, k-fold CV). The y axis is either a second GMR axis
(`has_y=true`) or the leading SVD of the x-deflated space.

All index vectors (`x1_cols`, `x_subset`, `y1_cols`) are **0-based `Int32`**.
Pass `Int32[]` for `x_subset` to use all rows.
Pass empty arrays for all `y_*` arguments when `has_y=false`.

Returns `(rotation, eigenvalues, column_names)` with labels
`GMR1`, `GMR2`|`SVD2`, `SVD3`, …
"""
function generalized_means_rotation(
    V::Matrix{Float64},
    x_model::Matrix{Float64},
    x_target::Vector{Float64},
    x1_cols::Vector{Int32},
    x_categorical::Bool,
    x_n_groups::Int32,
    x_subset::Vector{Int32},
    has_y::Bool,
    y_model::Matrix{Float64},
    y_target::Vector{Float64},
    y1_cols::Vector{Int32},
    y_categorical::Bool,
    y_n_groups::Int32;
    n_lambda::Int=50, k_folds::Int=5, lasso_eps::Float64=0.01
)
    vr, vc = size(V)
    xr, xc = size(x_model)
    yr, yc = size(y_model)
    _unpack_rotation(generalized_means_rotation(
        vec(V),        Int32(vr), Int32(vc),
        vec(x_model),  Int32(xr), Int32(xc),
        x_target,
        _sv_i32(x1_cols),
        x_categorical, x_n_groups,
        _sv_i32(x_subset),
        has_y,
        vec(y_model),  Int32(yr), Int32(yc),
        y_target,
        _sv_i32(y1_cols),
        y_categorical, y_n_groups,
        Int32(n_lambda), Int32(k_folds), lasso_eps))
end

# ── Window estimation ─────────────────────────────────────────────────────────

"""
    ccd_window(conversations; max_window=20, min_overlap=10) -> NamedTuple

Cross-covariance decay (CCD) window-size estimation: the ENA moving-window
size from the half-life decay lag of the noise-corrected Frobenius norm of
pooled cross-covariance matrices.

`conversations` is a vector of code matrices, one per conversation (rows in
sequence; all with the same number of columns).

Returns `(window_size, peak_lag, lag, frob, frob_sq_unbiased,
frob_unbiased_signed, total_weight)`; the curves are indexed by lag
`0:max_window`.
"""
function ccd_window(conversations::AbstractVector{<:AbstractMatrix{<:Real}};
                    max_window::Integer = 20, min_overlap::Integer = 10)
    n_codes = isempty(conversations) ? 0 : size(first(conversations), 2)
    all(c -> size(c, 2) == n_codes, conversations) ||
        throw(ArgumentError("ccd_window: all conversations must have the same number of columns"))
    data = Float64[x for c in conversations for x in vec(Matrix{Float64}(c))]
    rows = Int32[size(c, 1) for c in conversations]
    t = ccd_window(data, _sv_i32(rows), Int32(n_codes), Int32(max_window), Int32(min_overlap))
    (
        window_size          = Int(t[1]),
        peak_lag             = Int(t[2]),
        lag                  = collect(Float64, t[3]),
        frob                 = collect(Float64, t[4]),
        frob_sq_unbiased     = collect(Float64, t[5]),
        frob_unbiased_signed = collect(Float64, t[6]),
        total_weight         = collect(Float64, t[7]),
    )
end

end # module ENA
