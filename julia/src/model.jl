# The ENA pipeline: data → accumulation → model, as rENA's
# ena.accumulate.data() / ena.make.set() and qe-ena's ENA. Accumulation is
# TMA.jl's (the stanza window here, or a TMA.accumulate result); the model is
# libena's kernels (rotations, node positions) on LibQE's normalization.
#
#   acc   = ENA.accumulate(data, [:UserName, :Condition], [:ActivityNumber, :GroupName],
#                          codes; window_size = 4)
#   model = ENA.fit(acc)                                            # SVD
#   model = ENA.fit(acc; rotation = MeansRotation(:Condition, "FirstGame", "SecondGame"))
#   model = ENA.fit(acc; rotation = GeneralizedRotation(:Condition))
#   model.points, model.nodes, model.centroids
#
# `accumulate` and `fit` are not exported (Base has an accumulate; fit is a
# common generic): call them ENA.accumulate / ENA.fit.

# ── Accumulation ──────────────────────────────────────────────────────────────

"""
    ENAAccumulation

Each unit's stanza-window networks, not modeled (= rENA's
`ena.accumulate.data()`; qe-ena's `ENAAccumulation`):

- `connection_counts` — units × `choose(p, 2)` co-occurrences, summed per unit
  (columns follow `adjacency_key`: A & B, A & C, B & C, A & D, …).
- `row_connection_counts` — the same per data line.
- `unit_labels` — the `units` values joined with `"::"`, in order of first
  appearance; `codes`, `connection_names` (`"A & B"`), `adjacency_key`
  (`[(code_i, code_j), …]`).
- `meta` — one row per unit: the first line's non-code columns (a column table).
- `window_size`, `window_forward`, `binary` — the accumulation's settings.
"""
struct ENAAccumulation
    connection_counts::Matrix{Float64}
    row_connection_counts::Matrix{Float64}
    unit_labels::Vector{String}
    codes::Vector{String}
    connection_names::Vector{String}
    adjacency_key::Vector{Tuple{String,String}}
    meta::NamedTuple
    window_size::Float64
    window_forward::Float64
    binary::Bool
end

function Base.show(io::IO, a::ENAAccumulation)
    print(io, "ENAAccumulation(", length(a.unit_labels), " units × ",
          length(a.connection_names), " connections)")
end

_symbols(x) = x isa Union{Symbol,AbstractString} ? [Symbol(x)] : Symbol.(collect(x))

_window(w) = isinf(w) ? Int(typemax(Int32)) : Int(w)

function _check_window(name, w)
    (w isa Real && (isinf(w) ? w > 0 : (w >= 0 && isinteger(w)))) ||
        throw(ArgumentError("$name must be a whole number >= 0 (or Inf), got $(repr(w))"))
end

_keys(cols, syms, n) = [join((string(cols[c][i]) for c in syms), "::") for i in 1:n]

"""
    ENA.accumulate(data, units, conversations, codes;
                   window_size=4, window_forward=0, binary=true) -> ENAAccumulation

Stanza-window accumulation (= rENA's `ena.accumulate.data()`, qe-ena's
`accumulate()`): within each conversation, every line's codes co-occur with
the codes of the `window_size` lines up to and including it (and
`window_forward` lines after it); each unit's network is the sum over its
lines. `window_size = Inf` is the whole conversation so far.

`data` is any Tables.jl table; `units` and `conversations` are column names
(Symbol / String, or vectors of them — values are joined with `"::"`);
`codes` the code columns. The co-occurrences are TMA.jl's
`accumulate_stanza`. For TMA's context models (ordered networks, sender /
receiver weights, self-connections, …) use `TMA.accumulate`;
[`ENA.fit`](@ref) models either.
"""
function accumulate(data, units, conversations, codes;
                    window_size::Real = 4, window_forward::Real = 0, binary::Bool = true)
    cols = Tables.columntable(data)
    usyms, csyms, codesyms = _symbols(units), _symbols(conversations), _symbols(codes)
    isempty(codesyms) && throw(ArgumentError("codes must name at least one column"))
    allunique(codesyms) || throw(ArgumentError("codes contains duplicate column names"))
    for c in [usyms; csyms; codesyms]
        haskey(cols, c) || throw(KeyError(c))
    end
    for (what, syms) in (("units", usyms), ("conversations", csyms)), c in syms
        any(ismissing, cols[c]) && throw(ArgumentError("$what column $c contains missing values"))
    end
    for c in codesyms
        all(x -> x isa Real && isfinite(x), cols[c]) ||
            throw(ArgumentError("code column $c contains missing or non-numeric values"))
    end
    _check_window("window_size", window_size)
    _check_window("window_forward", window_forward)

    n = length(first(cols))
    codenames = String.(codesyms)
    names = LibQE.connection_names(codenames)
    codemat = Float64[cols[c][i] for i in 1:n, c in codesyms]
    ukeys, ckeys = _keys(cols, usyms, n), _keys(cols, csyms, n)
    labels = unique(ukeys)
    uindex = Dict(l => i for (i, l) in enumerate(labels))

    rows_of = Dict{String,Vector{Int}}()
    for (i, k) in enumerate(ckeys)
        push!(get!(rows_of, k, Int[]), i)
    end
    cc = zeros(length(labels), length(names))
    rcc = zeros(n, length(names))
    for k in unique(ckeys)
        rows = rows_of[k]
        co = TMA.accumulate_stanza(codemat[rows, :]; window_back = _window(window_size),
                                   window_forward = _window(window_forward), binary)
        rcc[rows, :] .= co
        for (r, i) in enumerate(rows)
            cc[uindex[ukeys[i]], :] .+= view(co, r, :)
        end
    end

    key = [Tuple(String.(split(nm, " & "; limit = 2))) for nm in names]
    metacols = [c for c in propertynames(cols) if !(c in codesyms)]
    first_rows = [findfirst(==(l), ukeys) for l in labels]
    meta = NamedTuple{Tuple(metacols)}(Tuple(cols[c][first_rows] for c in metacols))
    ENAAccumulation(cc, rcc, labels, codenames, names, key, meta,
                    Float64(window_size), Float64(window_forward), binary)
end

# ── Rotations ─────────────────────────────────────────────────────────────────

"""
    MeansRotation(group1, group2)
    MeansRotation(column, value1, value2)

[`ENA.fit`](@ref)'s `rotation`: the first dimension passes through the means
of two groups of units, the others are SVD of the deflated space (= rENA's
`ena.rotate.by.mean`; libena's `means_rotation`).

Groups are `Bool` vectors over the units, or vectors of unit labels; or the
units whose `meta` `column` is `value1` / `value2`.
"""
struct MeansRotation
    group1::Any
    group2::Any
end
MeansRotation(column::Symbol, value1, value2) = MeansRotation((column, value1), (column, value2))

"""
    GeneralizedRotation(x; y=nothing, select_2_groups=nothing, interactions=true,
                        n_lambda=50, k_folds=5, lasso_eps=0.01)

[`ENA.fit`](@ref)'s `rotation`: generalized means rotation (GMR) — the first
dimension is the direction most explained by a target variable after
controlling for covariates with a cross-validated lasso; with `y`, the second
is a GMR dimension for `y`, else SVD of the deflated space (= rENA's
`ena.rotate.by.generalized`; libena's `generalized_means_rotation`).

`x` (and `y`):

- a `Symbol` / `String` — a column of the accumulation's `meta`;
- a vector of `Symbol`s — `meta` columns: the target, then covariates;
- a vector of values, one per unit — the target;
- a table (e.g. a `NamedTuple` of vectors) — the target is its first column,
  covariates the rest.

A numeric target is a regression; any other a categorical one (between-group
scatter). Covariates enter as R's `model.matrix` builds them: numeric columns
as they are, others as treatment dummies over their sorted levels, and with
`interactions` all pairwise interactions. `select_2_groups = (a, b)` fits a
categorical `x` on the units in those two groups only.
"""
struct GeneralizedRotation
    x::Any
    y::Any
    select_2_groups::Any
    interactions::Bool
    n_lambda::Int
    k_folds::Int
    lasso_eps::Float64
end
GeneralizedRotation(x; y = nothing, select_2_groups = nothing, interactions::Bool = true,
                    n_lambda::Integer = 50, k_folds::Integer = 5, lasso_eps::Real = 0.01) =
    GeneralizedRotation(x, y, select_2_groups, interactions, n_lambda, k_folds, lasso_eps)

function _group(g, meta, labels)
    n = length(labels)
    if g isa Tuple{Symbol,Any}
        haskey(meta, g[1]) || throw(KeyError(g[1]))
        return meta[g[1]] .== Ref(g[2])
    end
    g isa AbstractVector{Bool} && length(g) == n && return collect(g)
    g isa AbstractVector{<:AbstractString} && return labels .∈ Ref(Set(String.(g)))
    throw(ArgumentError("a group must be a Bool vector over the $n units, unit labels, or (column, value)"))
end

function _rotate(r::MeansRotation, centered, meta, labels)
    g1, g2 = _group(r.group1, meta, labels), _group(r.group2, meta, labels)
    (any(g1) && any(g2)) || throw(ArgumentError("MeansRotation: each group needs at least one unit"))
    means_rotation(centered, [(Int32.(findall(g1) .- 1), Int32.(findall(g2) .- 1))])
end

_numeric(v) = all(x -> x isa Real && !(x isa Bool), v)

# One variable's model-matrix columns (R's model.matrix): numeric as is,
# otherwise treatment dummies over the sorted levels.
function _terms(name, v)
    _numeric(v) && return ([String(name)], [Float64.(v)])
    lv = sort(unique(string.(v)))
    s = string.(v)
    (["$name$l" for l in lv[2:end]], [Float64.(s .== l) for l in lv[2:end]])
end

function _model_matrix(vars, interactions)
    terms = [_terms(nm, v) for (nm, v) in vars]
    cols = reduce(vcat, [t[2] for t in terms])
    if interactions && length(terms) > 1
        for i in 1:length(terms)-1, j in i+1:length(terms), b in terms[j][2], a in terms[i][2]
            push!(cols, a .* b)
        end
    end
    reduce(hcat, cols), length(terms[1][2])
end

# (name => values) per variable: the target first.
function _variables(spec, meta, n)
    col(c) = (haskey(meta, Symbol(c)) || throw(KeyError(Symbol(c))); String(c) => collect(meta[Symbol(c)]))
    spec isa Union{Symbol,AbstractString} && return [col(spec)]
    spec isa AbstractVector{Symbol} && return [col(c) for c in spec]
    if spec isa AbstractVector
        length(spec) == n || throw(ArgumentError("a target vector needs one value per unit ($n)"))
        return ["x" => collect(spec)]
    end
    Tables.istable(spec) || throw(ArgumentError("GeneralizedRotation: unsupported x / y: $(typeof(spec))"))
    t = Tables.columntable(spec)
    [String(c) => collect(t[c]) for c in propertynames(t)]
end

# (model matrix, target, 0-based target columns, categorical, n groups)
function _gmr_axis(spec, meta, n, interactions, groups = nothing)
    vars = _variables(spec, meta, n)
    all(v -> length(v) == n, last.(vars)) ||
        throw(ArgumentError("GeneralizedRotation: every variable needs one value per unit ($n)"))
    mm, ntarget = _model_matrix(vars, interactions)
    target = last(vars[1])
    if _numeric(target)
        return mm, Float64.(target), Int32.(0:ntarget-1), false, Int32(0)
    end
    lv = unique(target)
    groups === nothing || (lv = [collect(groups); setdiff(lv, collect(groups))])
    enc = Float64[findfirst(==(x), lv) - 1 for x in target]
    mm, enc, Int32.(0:ntarget-1), true, Int32(length(lv))
end

function _rotate(r::GeneralizedRotation, centered, meta, labels)
    n = length(labels)
    g = r.select_2_groups
    g === nothing || length(g) == 2 || throw(ArgumentError("select_2_groups must be two groups"))
    xm, xt, x1, xcat, xn = _gmr_axis(r.x, meta, n, r.interactions, g)
    subset = Int32[]
    if g !== nothing
        target = last(_variables(r.x, meta, n)[1])
        rows = findall(in(collect(g)), target)
        length(rows) < 2 ? @warn("select_2_groups matches fewer than 2 units; using all units") :
                           (subset = Int32.(rows .- 1))
    end
    has_y = r.y !== nothing
    ym, yt, y1, ycat, yn = has_y ? _gmr_axis(r.y, meta, n, r.interactions) :
                                   (zeros(n, 1), zeros(n), Int32[0], false, Int32(0))
    generalized_means_rotation(centered, xm, xt, x1, xcat, xn, subset, has_y,
                               ym, yt, y1, ycat, yn;
                               n_lambda = r.n_lambda, k_folds = r.k_folds, lasso_eps = r.lasso_eps)
end

function _rotate(::Val{:svd}, centered, meta, labels)
    s = ena_svd(centered)
    k = min(size(centered)...)          # as prcomp: min(units, connections) axes
    (rotation = s.rotation[:, 1:k], eigenvalues = s.eigenvalues[1:k],
     column_names = s.column_names[1:k])
end

function _rotate(m::AbstractMatrix, centered, meta, labels)
    size(m, 1) == size(centered, 2) ||
        throw(ArgumentError("a rotation matrix needs one row per connection ($(size(centered, 2)))"))
    (rotation = Matrix{Float64}(m), eigenvalues = nothing,
     column_names = ["DIM$i" for i in 1:size(m, 2)])
end

# ── Model ─────────────────────────────────────────────────────────────────────

"""
    ENAModel

A fitted ENA model (= rENA's `ena.set`; qe-ena's fitted `ENA`, without the
trailing underscores):

- `connection_counts`, `row_connection_counts` — the accumulation's networks;
- `line_weights` — normalized networks (sphere norm);
- `points_for_projection` — the line weights, centered (zero networks stay at
  the origin);
- `rotation` — the first `dims` rotation vectors, connections × dims;
  `full_rotation` all of them; `rotation_names` (`SVD1`, `MR1`, `GMR1`, …);
  `eigenvalues` (or `nothing` for a given matrix);
- `points` — units × dims; `nodes` — codes × dims; `centroids` — units × dims
  (node weights × nodes); `weights` — the node weights;
- `variance` — each rotated dimension's share of the total variance;
- `center_vec`, `unit_labels`, `codes`, `connection_names`, `adjacency_key`,
  `meta`, `ordered`, `self_weight`, `accumulation`.
"""
struct ENAModel
    connection_counts::Matrix{Float64}
    row_connection_counts::Matrix{Float64}
    line_weights::Matrix{Float64}
    points_for_projection::Matrix{Float64}
    rotation::Matrix{Float64}
    full_rotation::Matrix{Float64}
    rotation_names::Vector{String}
    eigenvalues::Union{Vector{Float64},Nothing}
    points::Matrix{Float64}
    nodes::Matrix{Float64}
    centroids::Matrix{Float64}
    weights::Matrix{Float64}
    variance::Vector{Float64}
    center_vec::Vector{Float64}
    unit_labels::Vector{String}
    codes::Vector{String}
    connection_names::Vector{String}
    adjacency_key::Vector{Tuple{String,String}}
    meta::NamedTuple
    ordered::Bool
    self_weight::Float64
    accumulation::Any
end

function Base.show(io::IO, m::ENAModel)
    print(io, "ENAModel(", length(m.unit_labels), " units, ", length(m.codes), " codes, ",
          size(m.rotation, 2), " dims, ", m.ordered ? "ordered" : "unordered", ")")
end

const Accumulation = Union{ENAAccumulation,TMA.TMAAccumulation}

_ordered(a::ENAAccumulation) = false
_ordered(a::TMA.TMAAccumulation) = a.ordered

# Column k's 1-based (from, to) codes.
function _key_indices(key, codes)
    index = Dict(c => i for (i, c) in enumerate(codes))
    [index[a] for (a, _) in key], [index[b] for (_, b) in key]
end

# Unordered networks in a layout other than choose(p, 2) (self-connection
# columns) are placed by their adjacency key.
_by_key(ordered, key, codes) = !ordered && key != [(codes[i], codes[j]) for j in 2:length(codes) for i in 1:j-1]

function _variance(points)
    n = size(points, 1)
    k = size(points, 2)
    n < 2 && return fill(1 / k, k)
    v = [sum(abs2, c .- sum(c) / n) / (n - 1) for c in eachcol(points)]
    s = sum(v)
    s == 0 ? fill(1 / k, k) : v ./ s
end

"""
    ENA.fit(accumulation; dims=2, norm=:sphere, rotation=:svd, self_weight=2.0) -> ENAModel
    ENA.fit(data, units, conversations, codes; window_size=4, window_forward=0,
            binary=true, kwargs...) -> ENAModel

Fit an ENA model (= rENA's `ena.make.set()` / `model()`; qe-ena's `ENA.fit`)
to an [`ENA.accumulate`](@ref) result or a `TMA.accumulate` one — ordered
networks get ONA's directed node positions, unordered ones with
self-connection columns are placed by their adjacency key. With data, the
stanza accumulation runs first.

1. normalize: `norm = :sphere` (each network to unit length) or `:scale`
   (all divided by the longest);
2. center the networks that are not all zero (`ena.make.set`'s
   `center.align.to.origin = TRUE`, rENA's `model(exclude_zero_networks =
   TRUE)`): a unit whose network is all zeros is left out of the mean, stays
   at the origin, is left out of the node fit and has a zero centroid;
3. rotate: `:svd` (default), a [`MeansRotation`](@ref), a
   [`GeneralizedRotation`](@ref), or a matrix (connections × k);
4. project onto the first `dims` dimensions, and place the nodes by least
   squares so that the centroids (node weights × nodes) fit the points.

`self_weight` is a self-connection's weight in its code's node weight: `2`
(as rENA) counts it as a row and a column, `1` once. It changes only
networks with self-connections.
"""
function fit(acc::Accumulation; dims::Integer = 2, norm::Symbol = :sphere,
             rotation = :svd, self_weight::Real = 2.0)
    norm in (:sphere, :scale) || throw(ArgumentError("norm must be :sphere or :scale, got $(repr(norm))"))
    raw = acc.connection_counts
    # (LibQE returns its results as reshaped C++ vectors.)
    normed = Matrix{Float64}(norm === :sphere ? LibQE.normalize_networks(raw) : LibQE.scale_networks(raw))

    nonzero = vec(sum(abs, normed; dims = 2)) .!= 0
    center_vec = any(nonzero) ? vec(sum(normed[nonzero, :]; dims = 1)) ./ count(nonzero) :
                                zeros(size(normed, 2))
    centered = zeros(size(normed))
    any(nonzero) && (centered[nonzero, :] = LibQE.center_points(normed[nonzero, :]))

    labels = acc.unit_labels
    rot = _rotate(rotation isa Symbol ? Val(rotation) : rotation, centered, acc.meta, labels)
    full = rot.rotation
    1 <= dims <= size(full, 2) ||
        throw(ArgumentError("dims = $dims, but the rotation has $(size(full, 2)) dimensions"))
    rmat = full[:, 1:dims]
    t = centered * rmat

    codes = acc.codes
    ordered = _ordered(acc)
    key = acc.adjacency_key
    # Units with no connections carry no information about where the nodes go
    # (rENA's optimize(exclude_zero_networks = TRUE)): fit on the others and
    # give the empty units a zero centroid. Unordered models then shift the
    # nodes and centroids so the fitted units' mean centroid is at the origin,
    # as lws.positions.sq.R6 does; ordered models are fit on the other units
    # without that shift, as ONA 0.1.1 did. With no empty unit this is the
    # plain fit on every unit.
    fit_rows = any(nonzero) ? nonzero : trues(size(normed, 1))
    lw, tf = normed[fit_rows, :], t[fit_rows, :]
    pos = if ordered
        directed_node_positions(lw, tf, dims; self_weight)
    elseif _by_key(ordered, key, codes)
        from, to = _key_indices(key, codes)
        node_positions_by_key(lw, tf, dims, from, to, length(codes); self_weight)
    else
        node_positions(lw, tf, dims)
    end
    nodes, centroids, weights = Matrix{Float64}(pos.nodes), Matrix{Float64}(pos.centroids),
                               Matrix{Float64}(pos.weights)
    if !all(fit_rows)
        if !ordered
            mean_centroid = permutedims(vec(sum(centroids; dims = 1)) ./ size(centroids, 1))
            centroids = centroids .- mean_centroid
            nodes = nodes .- mean_centroid
        end
        full_c = zeros(size(normed, 1), size(centroids, 2)); full_c[fit_rows, :] = centroids
        full_w = zeros(size(normed, 1), size(weights, 2)); full_w[fit_rows, :] = weights
        centroids, weights = full_c, full_w
    end

    ENAModel(raw, acc.row_connection_counts, normed, centered, rmat, full,
             rot.column_names, rot.eigenvalues, t, nodes, centroids,
             weights, _variance(centered * full), center_vec, labels, codes,
             acc.connection_names, key, acc.meta, ordered, Float64(self_weight), acc)
end

_rotate(v::Val, args...) = throw(ArgumentError("rotation must be :svd, a MeansRotation, " *
                                               "a GeneralizedRotation or a matrix"))

function fit(data, units, conversations, codes; window_size::Real = 4,
             window_forward::Real = 0, binary::Bool = true, kwargs...)
    fit(accumulate(data, units, conversations, codes; window_size, window_forward, binary); kwargs...)
end

"""
    move_nodes_to_unit_circle(model::ENAModel; dims=(1, 2), mode=:equal) -> ENAModel

The model with its nodes moved onto a circle in the plane of two dimensions,
and the centroids recomputed for them (see the matrix method); the points are
unchanged, and so is `model`.
"""
function move_nodes_to_unit_circle(m::ENAModel; dims = (1, 2), mode = :equal)
    moved = if _by_key(m.ordered, m.adjacency_key, m.codes)
        from, to = _key_indices(m.adjacency_key, m.codes)
        move_nodes_to_unit_circle_by_key(m.line_weights, m.nodes, from, to;
                                         dims, mode, self_weight = m.self_weight)
    else
        move_nodes_to_unit_circle(m.line_weights, m.nodes; dims, mode,
                                  directed = m.ordered, self_weight = m.self_weight)
    end
    fields = Any[getfield(m, f) for f in fieldnames(ENAModel)]
    fields[findfirst(==(:nodes), fieldnames(ENAModel))] = moved.nodes
    fields[findfirst(==(:centroids), fieldnames(ENAModel))] = moved.centroids
    ENAModel(fields...)
end
