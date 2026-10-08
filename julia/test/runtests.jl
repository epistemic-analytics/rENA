using Test
using LinearAlgebra
using Random
using ENA

# ── Moved from LibQE.jl's tests with the code (libqe's phase 4a split) ────────

@testset "node_positions rejects NaN in adj_mats" begin
    adj = [0.1 0.2 NaN; 0.4 0.5 0.6; 0.7 0.8 0.9; 0.1 0.2 0.3; 0.4 0.5 0.6]
    t   = rand(5, 2)
    @test_throws ArgumentError node_positions(adj, t, 2)
end

@testset "node_positions rejects Inf in points" begin
    adj = rand(5, 6)
    t   = [1.0 2.0; Inf 0.0; 0.0 1.0; 1.0 0.0; 0.5 0.5]
    @test_throws ArgumentError node_positions(adj, t, 2)
end

@testset "node_positions succeeds on clean inputs" begin
    Random.seed!(7)
    adj = rand(5, 6)
    t   = rand(5, 2)
    r   = node_positions(adj, t, 2)
    @test size(r.nodes, 2) == 2
    @test all(isfinite, r.nodes)
end

@testset "directed_node_positions rejects NaN" begin
    lw  = [0.1 0.2 NaN 0.4; 0.5 0.6 0.7 0.8; 0.9 0.1 0.2 0.3; 0.4 0.5 0.6 0.7; 0.8 0.9 0.1 0.2]
    pts = rand(5, 2)
    @test_throws ArgumentError directed_node_positions(lw, pts, 2)
end

@testset "ena_svd rejects NaN input" begin
    pts = [1.0 2.0; NaN 0.0; 0.0 1.0; 1.0 0.0; 0.5 0.5]
    @test_throws ArgumentError ena_svd(pts)
end

@testset "ena_svd rejects Inf input" begin
    pts = [1.0 2.0; Inf 0.0; 0.0 1.0; 1.0 0.0; 0.5 0.5]
    @test_throws ArgumentError ena_svd(pts)
end

@testset "ena_svd succeeds on clean inputs" begin
    Random.seed!(8)
    pts = rand(5, 2)
    r   = ena_svd(pts)
    @test size(r.rotation) == (2, 2)
    @test all(isfinite, r.rotation)
end

# ── Added with the move: results of each function ─────────────────────────────

@testset "ena_svd matches prcomp's sdev^2 and is orthonormal" begin
    Random.seed!(11)
    pts = randn(12, 4)
    pts .-= sum(pts, dims = 1) ./ size(pts, 1)          # caller centers (as rENA)
    r   = ena_svd(pts)
    s   = svdvals(pts)
    @test r.eigenvalues ≈ s .^ 2 ./ (size(pts, 1) - 1)
    @test r.rotation' * r.rotation ≈ I(4)
    @test r.column_names == ["SVD1", "SVD2", "SVD3", "SVD4"]
end

@testset "deflate removes the axis" begin
    data = [1.0 0.0; 2.0 0.0; 3.0 0.0]
    out  = deflate(data, [1.0, 0.0])
    @test size(out) == (3, 2)
    @test all(abs.(out[:, 1]) .< 1e-12)
end

@testset "means_rotation labels and orthonormality" begin
    data = [1.0 0 0 1; 0 1 1 0; 2 1 1 2; 1 2 2 1]
    r = means_rotation(data, [(Int32[0, 1], Int32[2, 3])])
    @test r.column_names[1] == "MR1"
    @test size(r.rotation) == (4, 4)
    @test r.rotation' * r.rotation ≈ I(4) atol = 1e-10
end

@testset "orthogonal_svd and complete_rotation keep named axes" begin
    Random.seed!(12)
    data = randn(10, 4)
    axis = reshape(normalize([1.0, 1.0, 0.0, 0.0]), 4, 1)
    c = complete_rotation(data, axis, ["GMR1"])
    @test c.rotation[:, 1] ≈ vec(axis)                  # verbatim
    @test c.column_names == ["GMR1", "SVD2", "SVD3", "SVD4"]
    o = orthogonal_svd(data, axis, ["MR1"])
    @test abs(dot(o.rotation[:, 1], vec(axis))) ≈ 1.0   # same direction (QR sign)
    @test o.column_names[1] == "MR1"
end

@testset "generalized_means_rotation: numeric target gives GMR1/SVD2" begin
    V = [0.5 0.2 0.8; 0.3 0.7 0.1; 0.8 0.4 0.6; 0.1 0.9 0.3; 0.6 0.1 0.7;
         0.4 0.8 0.2; 0.7 0.3 0.9; 0.2 0.6 0.4; 0.9 0.5 0.1; 0.3 0.4 0.7]
    x = collect(1.0:10.0)
    r = generalized_means_rotation(V, reshape(x, 10, 1), x, Int32[0], false, Int32(0),
                                   Int32[], false, zeros(10, 1), zeros(10), Int32[],
                                   false, Int32(0); n_lambda = 10, k_folds = 3)
    @test size(r.rotation) == (3, 3)
    @test r.column_names[1:2] == ["GMR1", "SVD2"]
end

@testset "node position solvers: shapes" begin
    Random.seed!(13)
    pts = rand(6, 2)
    u = node_positions(rand(6, 3), pts, 2)              # 3 codes → choose_two = 3
    @test size(u.nodes) == (3, 2) && size(u.centroids) == (6, 2)
    d = directed_node_positions(rand(6, 9), pts, 2)     # 3 codes → 3² directed
    @test size(d.nodes) == (3, 2) && size(d.centroids) == (6, 2)
    # LibQE.jl's version of this one threw UndefVarError (pr/pc undefined).
    c = directed_node_positions_combine_pairs(rand(6, 9), pts, 2)
    @test size(c.nodes) == (3, 2) && size(c.centroids) == (6, 2)
    @test_throws ArgumentError directed_node_positions_combine_pairs(
        [NaN 0 0 0 0 0 0 0 0; rand(5, 9)], pts, 2)
end

@testset "ena_correlation" begin
    pts = reshape(collect(1.0:20.0), 10, 2)
    r = ena_correlation(pts, 2 .* pts)
    @test size(r) == (2, 3)
    @test r[:, 1] ≈ [1.0, 1.0] atol = 1e-8
end

@testset "ccd_window" begin
    Random.seed!(14)
    convos = Matrix{Float64}[]
    for _ in 1:2
        A = Float64.(rand(30) .< 0.4)
        B = [i > 1 && A[i - 1] == 1 && rand() < 0.8 ? 1.0 : Float64(rand() < 0.15) for i in 1:30]
        push!(convos, hcat(A, B, Float64.(rand(30) .< 0.3)))
    end
    r = ccd_window(convos; max_window = 12, min_overlap = 5)
    @test 1 <= r.window_size <= 12
    @test length(r.lag) == 13 && r.lag[1] == 0 && r.lag[end] == 12
    @test length(r.frob) == length(r.total_weight) == 13
    # conversations shorter than min_overlap → window 1
    short = ccd_window([[1.0 0 1; 0 1 0]]; max_window = 12, min_overlap = 5)
    @test short.window_size == 1 && short.peak_lag == 0
end
