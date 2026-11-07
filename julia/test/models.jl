# ENA.accumulate / ENA.fit (src/model.jl) against rENA: RS.data's stanza
# accumulation and models with SVD, means and generalized rotations
# (fixtures/ena-rs.json, from fixtures/ena-rs.R), and models of TMA.jl
# accumulations (fixtures/tma-models.json, rENA's model() on tma's
# accumulate(); a copy of python/tests/fixtures/tma-models.json, from
# python/tests/fixtures/tma-models.R).
using JSON
const TMA = ENA.TMA

rowmajor(rows) = permutedims(reduce(hcat, [Float64.(r) for r in rows]))
vecf(v) = Float64.(v)

# Dimensions are defined up to sign: flip each of `got`'s columns to `want`'s.
function aligned(got, want)
    s = [sign(sum(got[:, j] .* want[:, j])) for j in 1:size(want, 2)]
    got[:, 1:size(want, 2)] .* permutedims(s), s
end

const RS = JSON.parsefile(joinpath(@__DIR__, "fixtures", "ena-rs.json"))
const RS_DATA = NamedTuple(Symbol(k) => (eltype(v) <: Number || all(x -> x isa Number, v) ? Float64.(v) : String.(v))
                           for (k, v) in RS["data"])
const RS_CODES = Symbol.(RS["codes"])
rs_acc(; kw...) = ENA.accumulate(RS_DATA, [:UserName, :Condition], [:ActivityNumber, :GroupName],
                                 RS_CODES; window_size = 4, kw...)

@testset "ENA.accumulate matches rENA's ena.accumulate.data (RS.data)" begin
    a = rs_acc()
    @test a isa ENAAccumulation
    @test sort(a.unit_labels) == sort(String.(RS["units"]))
    order = [findfirst(==(l), a.unit_labels) for l in RS["units"]]
    @test a.connection_counts[order, :] ≈ rowmajor(RS["connection_counts"])
    @test a.connection_names[1:3] == ["Data & Technical.Constraints", "Data & Performance.Parameters",
                                      "Technical.Constraints & Performance.Parameters"]
    @test a.adjacency_key[1] == ("Data", "Technical.Constraints")
    @test size(a.row_connection_counts) == (length(RS_DATA.UserName), 15)
    for (i, l) in enumerate(a.unit_labels)         # unit networks = sums of their lines
        rows = findall(==(l), RS_DATA.UserName .* "::" .* RS_DATA.Condition)
        @test vec(sum(a.row_connection_counts[rows, :]; dims = 1)) ≈ a.connection_counts[i, :]
    end
    @test a.meta.Condition[1] == split(a.unit_labels[1], "::")[2]
    @test !haskey(a.meta, :Data)
end

@testset "ENA.fit matches rENA's ena.make.set (RS.data, $name)" for (name, rotation) in (
        "svd"             => :svd,
        "means"           => MeansRotation(:Condition, "FirstGame", "SecondGame"),
        "gmr_categorical" => GeneralizedRotation(:Condition),
        "gmr_numeric"     => GeneralizedRotation(Symbol("CONFIDENCE.Change")),
        "gmr_covariate"   => GeneralizedRotation([:Condition, Symbol("CONFIDENCE.Pre")]),
        "gmr_y"           => GeneralizedRotation(:Condition; y = Symbol("CONFIDENCE.Change")),
        "gmr_multigroup"  => GeneralizedRotation(:ConfidenceLevel),
        "gmr_select_2"    => GeneralizedRotation(:ConfidenceLevel; select_2_groups = ("low", "high")))
    ref = RS[name]
    m = ENA.fit(rs_acc(); rotation)
    order = [findfirst(==(l), m.unit_labels) for l in RS["units"]]
    @test m.line_weights[order, :] ≈ rowmajor(ref["line_weights"])
    @test m.center_vec ≈ vecf(ref["center_vec"])
    rot, s = aligned(m.rotation, rowmajor(ref["rotation"]))
    @test rot ≈ rowmajor(ref["rotation"]) atol = 1e-10
    @test m.points[order, :] .* permutedims(s) ≈ rowmajor(ref["points"]) atol = 1e-10
    @test m.nodes .* permutedims(s) ≈ rowmajor(ref["nodes"]) atol = 1e-10
    @test m.centroids[order, :] .* permutedims(s) ≈ rowmajor(ref["centroids"]) atol = 1e-10
    @test m.variance ≈ vecf(ref["variance"])[1:length(m.variance)] atol = 1e-10
    ref["eigenvalues"] === nothing ||
        @test m.eigenvalues ≈ vecf(ref["eigenvalues"])[1:length(m.eigenvalues)] atol = 1e-10
end

@testset "ENA.fit options and errors" begin
    a = rs_acc()
    m = ENA.fit(a)
    @test size(m.points) == (48, 2) && size(m.nodes) == (6, 2) && size(m.rotation) == (15, 2)
    @test m.rotation_names[1:2] == ["SVD1", "SVD2"]
    @test size(ENA.fit(a; dims = 4).points, 2) == 4
    @test ENA.fit(RS_DATA, [:UserName, :Condition], [:ActivityNumber, :GroupName], RS_CODES).points ≈ m.points
    # Groups as Bool vectors or unit labels: the same rotation.
    first_game = a.meta.Condition .== "FirstGame"
    r1 = ENA.fit(a; rotation = MeansRotation(:Condition, "FirstGame", "SecondGame")).rotation
    @test ENA.fit(a; rotation = MeansRotation(first_game, .!first_game)).rotation ≈ r1
    @test ENA.fit(a; rotation = MeansRotation(a.unit_labels[first_game], a.unit_labels[.!first_game])).rotation ≈ r1
    # A given rotation matrix, and a target given as values.
    @test ENA.fit(a; rotation = m.full_rotation).points ≈ m.points
    @test ENA.fit(a; rotation = GeneralizedRotation(a.meta.Condition)).rotation ≈
          ENA.fit(a; rotation = GeneralizedRotation(:Condition)).rotation
    @test ENA.fit(a; norm = :scale).line_weights ≈ ENA.LibQE.scale_networks(a.connection_counts)
    @test_throws ArgumentError ENA.fit(a; dims = 0)
    @test_throws ArgumentError ENA.fit(a; dims = 16)
    @test_throws ArgumentError ENA.fit(a; norm = :none)
    @test_throws ArgumentError ENA.fit(a; rotation = :pca)
    @test_throws ArgumentError ENA.fit(a; rotation = MeansRotation(:Condition, "FirstGame", "ThirdGame"))
    @test_throws KeyError ENA.fit(a; rotation = GeneralizedRotation(:Nope))
    # Unit-circle move: the matrix method's result, the model otherwise unchanged.
    u = move_nodes_to_unit_circle(m)
    ref = move_nodes_to_unit_circle(m.line_weights, m.nodes)
    @test u.nodes ≈ ref.nodes && u.centroids ≈ ref.centroids && u.points == m.points
end

@testset "ENA.accumulate input checks and windows" begin
    d = (u = ["a", "a", "b", "b"], c = [1, 1, 1, 1], A = [1, 0, 1, 1], B = [0, 1, 1, 0])
    @test ENA.accumulate(d, :u, :c, [:A, :B]; window_size = 1).connection_counts == reshape([0.0, 1.0], 2, 1)
    @test ENA.accumulate(d, :u, :c, [:A, :B]; window_size = 2).connection_counts == reshape([1.0, 2.0], 2, 1)
    @test ENA.accumulate(d, :u, :c, [:A, :B]; window_size = Inf).connection_counts ==
          ENA.accumulate(d, :u, :c, [:A, :B]; window_size = 4).connection_counts
    @test_throws KeyError ENA.accumulate(d, :u, :c, [:A, :Z])
    @test_throws ArgumentError ENA.accumulate(d, :u, :c, [:A, :A])
    @test_throws ArgumentError ENA.accumulate(d, :u, :c, [:A, :B]; window_size = 1.5)
    @test_throws ArgumentError ENA.accumulate((u = d.u, c = d.c, A = [1, NaN, 0, 1], B = d.B), :u, :c, [:A, :B])
    @test_throws ArgumentError ENA.accumulate((u = ["a", missing, "b", "b"], c = d.c, A = d.A, B = d.B),
                                              :u, :c, [:A, :B])
end

# ── Models of TMA.jl accumulations ────────────────────────────────────────────

const TM = JSON.parsefile(joinpath(@__DIR__, "fixtures", "tma-models.json"))
const TOY = (u = String.(TM["toy"]["u"]), c = String.(TM["toy"]["c"]), A = vecf(TM["toy"]["A"]),
             B = vecf(TM["toy"]["B"]), C = vecf(TM["toy"]["C"]))
tma_acc(; kw...) = TMA.accumulate(TOY, :u, :c, [:A, :B, :C];
                                  tensor = TMA.context_tensor(TOY; default_window = 3),
                                  weight_by = "product", kw...)

@testset "ENA.fit of TMA.accumulate matches rENA's model() ($name)" for (name, kw) in (
        "ordered"               => (ordered = true,),
        "ordered_self_weight_1" => (ordered = true,),
        "self_connections"      => (self_connections = true,),
        "plain"                 => (;))
    ref = TM[name]
    acc = tma_acc(; kw...)
    m = ENA.fit(acc; self_weight = ref["self_weight"])
    @test m.ordered == get(kw, :ordered, false)
    @test [collect(k) for k in m.adjacency_key] == ref["adjacency_key"]
    order = [findfirst(==(l), m.unit_labels) for l in ref["units"]]
    @test m.connection_counts[order, :] ≈ rowmajor(ref["connection_counts"])
    @test m.line_weights[order, :] ≈ rowmajor(ref["line_weights"])
    pts, s = aligned(m.points[order, :], rowmajor(ref["points"]))
    @test pts ≈ rowmajor(ref["points"]) atol = 1e-10
    @test m.nodes .* permutedims(s) ≈ rowmajor(ref["nodes"]) atol = 1e-10
    # The unit-circle move places self-connection columns by their key.
    u = move_nodes_to_unit_circle(m)
    @test size(u.nodes) == size(m.nodes) && u.points == m.points
end

# ── Units with an empty network ───────────────────────────────────────────────
# fixtures/zero-networks.json (a copy of python/tests/fixtures/zero-networks.json,
# from python/tests/fixtures/zero-networks.R): rENA's model() (SVD) on RS.data
# accumulated by UserName, Condition and GroupName at window 4 -- two units
# with an all-zero network in the unordered set, one in the ordered set. Such
# a unit follows ena.make.set(center.align.to.origin = TRUE), the rule of
# rENA's model(exclude_zero_networks = TRUE) and of ONA 0.1.1: it stays at the
# origin, is left out of the centering mean and the node fit, and has a zero
# centroid; unordered models shift the nodes and centroids so the fitted
# units' mean centroid is at the origin.

const ZN = JSON.parsefile(joinpath(@__DIR__, "fixtures", "zero-networks.json"))
const ZN_CODES = String.(ZN["codes"])

# The accumulations rebuilt from R's connection counts (per-line counts are
# not needed by fit).
function zn_acc(case, ordered; keep = trues(length(case["units"])))
    cc = rowmajor(case["connection_counts"])[keep, :]
    labels = String.(case["units"])[keep]
    key = [Tuple(String.(k)) for k in case["adjacency_key"]]
    names = [a * " & " * b for (a, b) in key]
    n, p = size(cc, 1), length(ZN_CODES)
    if ordered
        TMA.TMAAccumulation(cc, zeros(n, p), nothing, nothing, zeros(0, size(cc, 2)), zeros(0, p),
                            nothing, nothing, labels, ZN_CODES, names, key, (;), true, false, "product")
    else
        ENAAccumulation(cc, zeros(0, size(cc, 2)), labels, ZN_CODES, names, key, (;), 4.0, 0.0, true)
    end
end
zn_empty(case) = [i in case["empty"] for i in 1:length(case["units"])]

@testset "ENA.fit with empty units matches rENA's model() ($name)" for (name, ordered) in
        ("unordered" => false, "ordered" => true)
    ref = ZN[name]
    empty = zn_empty(ref)
    @test count(empty) == (ordered ? 1 : 2)
    m = ENA.fit(zn_acc(ref, ordered); dims = 6)
    @test m.ordered == ordered
    @test m.line_weights ≈ rowmajor(ref["line_weights"]) atol = 1e-12
    pts, s = aligned(m.points, rowmajor(ref["points"]))
    @test pts ≈ rowmajor(ref["points"]) atol = 1e-10
    @test m.nodes .* permutedims(s) ≈ rowmajor(ref["nodes"]) atol = 1e-10
    @test m.centroids .* permutedims(s) ≈ rowmajor(ref["centroids"]) atol = 1e-10
    @test m.eigenvalues[1:6] ≈ vecf(ref["eigenvalues"]) atol = 1e-10
    @test m.variance[1:6] ≈ vecf(ref["variance"]) atol = 1e-10
    # the empty units: at the origin, zero centroids, out of the centre vector
    @test all(m.points_for_projection[empty, :] .== 0)
    @test all(m.points[empty, :] .== 0)
    @test all(m.centroids[empty, :] .== 0)
    @test m.center_vec ≈ vec(sum(m.line_weights[.!empty, :]; dims = 1)) ./ count(.!empty)
    # dropping them beforehand gives the same nodes and the same points and
    # centroids for the others
    d = ENA.fit(zn_acc(ref, ordered; keep = .!empty); dims = 6)
    dpts, ds = aligned(d.points, m.points[.!empty, :])
    @test dpts ≈ m.points[.!empty, :] atol = 1e-10
    @test d.nodes .* permutedims(ds) ≈ m.nodes atol = 1e-10
    @test d.centroids .* permutedims(ds) ≈ m.centroids[.!empty, :] atol = 1e-10
    ordered || @test vec(sum(m.centroids[.!empty, :]; dims = 1)) ./ count(.!empty) ≈ zeros(6) atol = 1e-10
end
