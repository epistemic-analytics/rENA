/**
 * Tests for rena-wasm's libena module (dist/libena.*): rotations, node
 * positions and CCD, plus libtma's accumulation compiled into the same module.
 * Run `npm run build` first.
 *
 * The first block moved from libqe-wasm's test/basic.test.js with the code
 * (libqe's phase 4a split), unchanged.  The parity block checks that this
 * module and libqe-wasm's own copy (kept until libqe 0.2.0) give identical
 * results, and that loadENA() routes these functions to libena.
 */
import createLibENA from '../dist/libena.js';
import loadLibQE from '@qe-libs/libqe-wasm';
import loadENA from '../src/index.js';

let qe;
beforeAll(async () => { qe = await createLibENA(); });

// ── Modeling — node_positions regression ──────────────────────────────────────

test('node_positions: nodes.cols equals num_dims when num_dims passed explicitly', () => {
    // 3 units × 3 connections (choose(3,2)), 2 dimensions
    // adj_mats: 3×3 row-major
    const adj  = new Float64Array([1,0,0, 0,1,0, 0,0,1]);
    // t (unit points): 3×2 row-major
    const t    = new Float64Array([0.1,0.2, 0.3,0.4, 0.5,0.6]);
    const r    = qe.node_positions(adj, 3, 3, t, 3, 2, 2);
    expect(r.nodes.rows).toBe(3);   // 3 codes → 3 nodes
    expect(r.nodes.cols).toBe(2);   // 2 dimensions
    expect(r.nodes.data.length).toBe(6);
});

test('node_positions: nodes.cols is non-zero when num_dims omitted (defaults to t_cols)', () => {
    // Regression: Embind passes 0 for missing int args; omitting num_dims used to
    // produce { rows: 3, cols: 0 } because ssX was created as 0×num_nodes.
    const adj  = new Float64Array([1,0,0, 0,1,0, 0,0,1]);
    const t    = new Float64Array([0.1,0.2, 0.3,0.4, 0.5,0.6]);
    // Simulate the caller omitting num_dims (Embind receives 0)
    const r    = qe.node_positions(adj, 3, 3, t, 3, 2, 0);
    expect(r.nodes.cols).toBeGreaterThan(0);
    expect(r.nodes.cols).toBe(2);
});

// ── Rotation ──────────────────────────────────────────────────────────────────

test('ena_svd: returns rotation matrix and eigenvalues', () => {
    // 3 units × 2 connection dimensions
    const data = new Float64Array([1,0, 0,1, 1,1]);
    const r    = qe.ena_svd(data, 3, 2);
    expect(r.rotation.rows).toBe(2);
    expect(r.rotation.cols).toBe(2);
    expect(r.eigenvalues.length).toBe(2);
    expect(r.column_names.length).toBe(2);
});

test('ena_svd: does not throw for exact value 0.025 (regression: Jacobi NaN via 0/0)', () => {
    // A 2×3 rank-1 matrix whose Jacobi iteration converges to an all-zero
    // 2×2 sub-block (aqq = arr = aqr = 0 exactly).  The `<` skip condition
    // evaluated `0 < 0` as false, fell through to theta = 0/0 = NaN, and
    // terminated via std::terminate.  Fixed by using `<=`.
    const bad = new Float64Array([0.296, 0.025, -0.274, -0.296, -0.025, 0.274]);
    expect(() => qe.ena_svd(bad, 2, 3)).not.toThrow();
    const r = qe.ena_svd(bad, 2, 3);
    expect(r.eigenvalues.length).toBe(3);
    // One non-zero eigenvalue; the other two are zero (rank-1 input)
    const evSorted = [...r.eigenvalues].sort((a, b) => b - a);
    expect(evSorted[0]).toBeGreaterThan(0.1);
    expect(evSorted[1]).toBeCloseTo(0, 10);
    expect(evSorted[2]).toBeCloseTo(0, 10);
});

test('deflate: removes variance along axis', () => {
    // data aligned with first standard basis vector; deflating that axis
    // should zero out the first column
    const data = new Float64Array([1,0, 2,0, 3,0]);  // 3×2 row-major
    const axis = new Float64Array([1, 0]);
    const out  = qe.deflate(data, 3, 2, axis);
    expect(out.rows).toBe(3);
    expect(out.cols).toBe(2);
    // col 0 of output should be near zero
    [0, 2, 4].forEach(i => expect(Math.abs(out.data[i])).toBeCloseTo(0, 8));
});

test('means_rotation: returns rotation with column_names', () => {
    // 4 units × 4 ENA dims (row-major).  Group a = rows 0–1, group b = rows 2–3.
    const data = new Float64Array([
        1, 0, 0, 1,   // unit 0 — group a
        0, 1, 1, 0,   // unit 1 — group a
        2, 1, 1, 2,   // unit 2 — group b
        1, 2, 2, 1,   // unit 3 — group b
    ]);
    const groupPairs = [{ a: new Int32Array([0, 1]), b: new Int32Array([2, 3]) }];
    const r = qe.means_rotation(data, 4, 4, groupPairs);
    expect(r.rotation.rows).toBe(4);
    expect(r.rotation.cols).toBe(4);
    expect(r.eigenvalues.length).toBe(4);
    expect(r.column_names[0]).toBe('MR1');
});

test('generalized_means_rotation: numeric target returns GMR1/SVD2', () => {
    // 10 units × 3 ENA dims, numeric target, no covariates, no y axis.
    // Use diverse floating-point data to avoid numerical edge cases in the
    // no-BLAS/LAPACK WASM environment (e.g. near-zero after orthogonalization).
    const V = new Float64Array([
        0.5, 0.2, 0.8,
        0.3, 0.7, 0.1,
        0.8, 0.4, 0.6,
        0.1, 0.9, 0.3,
        0.6, 0.1, 0.7,
        0.4, 0.8, 0.2,
        0.7, 0.3, 0.9,
        0.2, 0.6, 0.4,
        0.9, 0.5, 0.1,
        0.3, 0.4, 0.7,
    ]);
    const xTarget = new Float64Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    const xModel  = xTarget;                   // 10×1 model matrix
    const x1Cols  = new Int32Array([0]);        // only column is target
    const xSubset = new Int32Array([]);         // use all rows
    const dummy   = new Float64Array(10);       // ignored y params
    const dummy0  = new Int32Array([]);

    const r = qe.generalized_means_rotation(
        V,      10, 3,
        xModel, 10, 1, xTarget, x1Cols,
        /*x_categorical=*/false, /*x_n_groups=*/0, xSubset,
        /*has_y=*/false,
        dummy, 10, 1, dummy, dummy0,
        /*y_categorical=*/false, /*y_n_groups=*/0,
        /*n_lambda=*/10, /*k_folds=*/3, /*lasso_eps=*/0.01
    );
    expect(r.rotation.rows).toBe(3);
    expect(r.rotation.cols).toBe(3);
    expect(r.eigenvalues.length).toBe(3);
    expect(r.column_names[0]).toBe('GMR1');
    expect(r.column_names[1]).toBe('SVD2');
});

test('ccd_window: estimates a window and returns per-lag curves', () => {
    // Two conversations × 30 rows, 3 codes. Code B tends to follow code A at
    // lag 1 (with decay), so the corrected covariance peaks early and decays.
    let seed = 3;
    const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
    const flat = []; let nRows = 0;
    const groupSizes = [], rowIndices = [];
    for (let c = 0; c < 2; c++) {
        let prevA = 0;
        for (let i = 0; i < 30; i++) {
            const A = rnd() < 0.4 ? 1 : 0;
            const B = (prevA === 1 && rnd() < 0.8) ? 1 : (rnd() < 0.15 ? 1 : 0);
            const Cc = rnd() < 0.3 ? 1 : 0;
            flat.push(A, B, Cc);
            rowIndices.push(nRows++);
            prevA = A;
        }
        groupSizes.push(30);
    }
    const r = qe.ccd_window(flat, nRows, 3, groupSizes, rowIndices, 12, 5);

    expect(r.window_size).toBeGreaterThanOrEqual(1);
    expect(r.window_size).toBeLessThanOrEqual(12);
    expect(r.peak_lag).toBeGreaterThanOrEqual(1);
    // Curves are indexed by lag 0..max_window.
    expect(r.lag.length).toBe(13);
    expect(r.frob.length).toBe(13);
    expect(r.frob_unbiased_signed.length).toBe(13);
    expect(r.total_weight.length).toBe(13);
    expect(r.lag[0]).toBe(0);
    expect(r.lag[12]).toBe(12);
});

test('ccd_window: conversations shorter than min_overlap default to window 1', () => {
    const r = qe.ccd_window([1, 0, 1, 0, 1, 0], 2, 3, [2], [0, 1], 12, 5);
    expect(r.window_size).toBe(1);
    expect(r.peak_lag).toBe(0);
});

// ── parity with libqe-wasm, and routing ───────────────────────────────────────

describe('libena module (libena + libtma) vs libqe-wasm', () => {
    let libqe;
    beforeAll(async () => { libqe = await loadLibQE(); });

    // Same inputs as the tests above; each call must give identical output.
    const pts  = new Float64Array([1,0,0,1, 0,1,1,0, 2,1,1,2, 1,2,2,1]);
    const adj  = new Float64Array([1,0,0, 0,1,0, 0,0,1]);
    const t    = new Float64Array([0.1,0.2, 0.3,0.4, 0.5,0.6]);
    const lw   = new Float64Array([1,0,2,0, 0,1,0,3, 2,2,1,0]);
    const codes   = new Float64Array([1,0,2, 0,1,1, 2,1,0, 1,1,1, 0,2,1]);   // 5 × 3
    const rowConn = new Float64Array([0,1,0, 2,0,4, 0,0,0,  0,0,9, 0.5,0,0, 1,0,0]);  // 2 × 9
    const cases = {
        ena_svd:            m => m.ena_svd(pts, 4, 4),
        deflate:            m => m.deflate(pts, 4, 4, new Float64Array([0.5,0.5,0.5,0.5])),
        orthogonal_svd:     m => m.orthogonal_svd(pts, 4, 4, new Float64Array([1,0,0,0]), 4, 1, ['MR1']),
        complete_rotation:  m => m.complete_rotation(pts, 4, 4, new Float64Array([0,1,0,0]), 4, 1, ['GMR1']),
        means_rotation:     m => m.means_rotation(pts, 4, 4,
                                    [{ a: new Int32Array([0, 1]), b: new Int32Array([2, 3]) }]),
        node_positions:     m => m.node_positions(adj, 3, 3, t, 3, 2, 2),
        directed_node_positions: m => m.directed_node_positions(lw, 3, 4, t, 3, 2, 2),
        directed_node_positions_combine_pairs:
                            m => m.directed_node_positions_combine_pairs(lw.subarray(0, 8), 2, 4,
                                    t.subarray(0, 4), 2, 2, 2),
        ena_correlation:    m => m.ena_correlation(Array.from(t), 3, 2, [0.2,0.1, 0.4,0.5, 0.5,0.7], 3, 2, 0.95),
        ccd_window:         m => m.ccd_window([1,0,1, 0,1,1, 1,1,0, 0,0,1, 1,0,0, 0,1,0], 6, 3,
                                    [6], [0,1,2,3,4,5], 3, 2),
        // libtma (phase 5): compiled in from tma's shared bindings
        accumulate_stanza:  m => m.accumulate_stanza(codes, 5, 3, 3, 1, false, false),
        accumulate_tensor_unit:
                            m => m.accumulate_tensor_unit([1, 3], [2], [], [], [], new Int32Array(0), 5, 0,
                                    [2, 3, 4], codes, 5, 3, [0, 1, 2, 3, 4], true),
        aggregate_row_connections:
                            m => m.aggregate_row_connections(rowConn, 2, 9, 3, false, 'sqrt'),
        finalize_row_connections:
                            m => m.finalize_row_connections(rowConn, 2, 9, 3, true, 'log1p'),
        rolling_window_sum: m => m.rolling_window_sum(codes, 5, 3, 3),
    };

    test.each(Object.keys(cases))('%s matches libqe-wasm', name => {
        expect(cases[name](qe)).toEqual(cases[name](libqe));
    });

    test('loadENA() exposes libena and libqe-wasm functions on one module', async () => {
        const ena = await loadENA();
        for (const name of Object.keys(cases))
            expect(cases[name](ena.qe)).toEqual(cases[name](qe));
        // libqe-wasm still provides everything else
        expect(ena.qe.choose_two(4)).toBe(6);
        expect(ena.qe.connection_names(['A', 'B', 'C'])).toEqual(['A & B', 'A & C', 'B & C']);
    });
});
