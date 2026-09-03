/**
 * Integration tests for @qe-libs/rena-wasm.
 *
 * Uses a small synthetic dataset with two units, two conversations, and
 * three binary codes — enough to exercise the full pipeline without
 * depending on real RS.data.
 *
 * Field names match the R ena.set structure:
 *   model.connectionCounts      = R set$connection.counts (raw)
 *   model.rowConnectionCounts   = R set$model$row.connection.counts (raw)
 *   model.lineWeights           = R set$line.weights (normed)
 *   model.points                = R set$points (projected unit positions)
 *   model.rotationMatrix        = R set$rotation.matrix
 *   model.model.centroids       = R set$model$centroids (LWS)
 *   model.model.unitLabels      = R set$model$unit.labels
 *   model.model.variance        = R set$model$variance
 *   model.rotation.nodes        = R set$rotation$nodes (code positions)
 *   model.rotation.columnNames  = R rotation.matrix column names (SVD1, MR1, ...)
 *   model.rotation.eigenvalues  = R set$rotation$eigenvalues
 *   model.rotation.centerVec    = R set$rotation$center.vec
 */
import loadENA from '../src/index.js';

// ── fixture ───────────────────────────────────────────────────────────────────

// 6 rows, 2 conversations (A, B), 2 units (U1, U2), 3 codes
const ROWS = [
    { Condition: 'A', GroupName: 'G1', UserName: 'U1', Score: 90, D: 1, T: 1, P: 0 },
    { Condition: 'A', GroupName: 'G1', UserName: 'U1', Score: 90, D: 1, T: 0, P: 1 },
    { Condition: 'A', GroupName: 'G1', UserName: 'U2', Score: 75, D: 0, T: 1, P: 1 },
    { Condition: 'B', GroupName: 'G1', UserName: 'U1', Score: 90, D: 1, T: 1, P: 0 },
    { Condition: 'B', GroupName: 'G1', UserName: 'U2', Score: 75, D: 0, T: 0, P: 1 },
    { Condition: 'B', GroupName: 'G1', UserName: 'U2', Score: 75, D: 1, T: 1, P: 1 },
];

const OPTS = {
    codes:         ['D', 'T', 'P'],
    units:         ['UserName'],
    conversations: ['Condition', 'GroupName'],
    window:        4,
    dims:          2,
};

let ena;
beforeAll(async () => { ena = await loadENA(); });

// ── accumulate ────────────────────────────────────────────────────────────────

test('accumulate: returns correct shape', () => {
    const { connectionCounts, rowConnectionCounts, nUnits, nConnections, unitLabels, connectionNames } =
        ena.accumulate(ROWS, OPTS);

    expect(nUnits).toBe(2);                     // U1, U2
    expect(nConnections).toBe(3);               // choose_two(3) = 3
    expect(connectionCounts.length).toBe(6);    // 2 × 3
    expect(rowConnectionCounts.length).toBe(18);// 6 × 3
    expect(unitLabels).toEqual(['U1', 'U2']);
    expect(connectionNames).toEqual(['D & T', 'D & P', 'T & P']);
});

test('accumulate: all values are non-negative', () => {
    const { connectionCounts, rowConnectionCounts } = ena.accumulate(ROWS, OPTS);
    expect(Array.from(connectionCounts).every(v => v >= 0)).toBe(true);
    expect(Array.from(rowConnectionCounts).every(v => v >= 0)).toBe(true);
});

test('accumulate: rowConnectionCounts roll up to connectionCounts by unit', () => {
    const { connectionCounts, rowConnectionCounts, nConnections, unitLabels } =
        ena.accumulate(ROWS, OPTS);
    const rolledUp = new Float64Array(connectionCounts.length);

    for (let r = 0; r < ROWS.length; r++) {
        const unitIndex = unitLabels.indexOf(ROWS[r].UserName);
        for (let c = 0; c < nConnections; c++) {
            rolledUp[unitIndex * nConnections + c] += rowConnectionCounts[r * nConnections + c];
        }
    }

    expect(Array.from(rolledUp)).toEqual(Array.from(connectionCounts));
});

test('accumulate: metaData has one entry per unit', () => {
    const { metaData, nUnits } = ena.accumulate(ROWS, OPTS);
    expect(metaData.length).toBe(nUnits);
});

test('accumulate: metaData excludes code and unit columns', () => {
    const { metaData } = ena.accumulate(ROWS, OPTS);
    // Score is a metadata column; code cols (D, T, P) and unit col (UserName) must not appear
    expect('Score' in metaData[0]).toBe(true);
    expect('D' in metaData[0]).toBe(false);
    expect('UserName' in metaData[0]).toBe(false);
});

// ── fit: output shapes ────────────────────────────────────────────────────────

test('fit: points shape is nUnits × dims', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.points.length).toBe(model.nUnits * model.dims);
    expect(model.nUnits).toBe(2);
    expect(model.dims).toBe(2);
});

test('fit: rotation.nodes shape is nCodes × dims', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.rotation.nodes.length).toBe(OPTS.codes.length * OPTS.dims);
});

test('fit: lineWeights shape is nUnits × nConnections', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.lineWeights.length).toBe(model.nUnits * model.nConnections);
    expect(model.nConnections).toBe(3);
});

test('fit: connectionCounts shape is nUnits × nConnections', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.connectionCounts.length).toBe(model.nUnits * model.nConnections);
});

test('fit: rowConnectionCounts shape is nRows × nConnections', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.rowConnectionCounts.length).toBe(ROWS.length * model.nConnections);
    expect(model.model.rowConnectionCounts).toBe(model.rowConnectionCounts);
});

test('fit: rotationMatrix shape is nConnections × dims', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.rotationMatrix.length).toBe(model.nConnections * model.dims);
});

test('fit: connectionNames matches codes pairs', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.connectionNames).toEqual(['D & T', 'D & P', 'T & P']);
});

test('fit: model.unitLabels in order of first appearance', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.model.unitLabels).toEqual(['U1', 'U2']);
});

test('fit: rotation.columnNames start with SVD for default rotation', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.rotation.columnNames[0]).toBe('SVD1');
    expect(model.rotation.columnNames[1]).toBe('SVD2');
});

test('fit: model.variance sums to 1', () => {
    const model = ena.fit(ROWS, OPTS);
    const total = model.model.variance.reduce((a, b) => a + b, 0);
    expect(total).toBeCloseTo(1, 10);
});

test('fit: rotation.centerVec length equals nConnections', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.rotation.centerVec.length).toBe(model.nConnections);
});

test('fit: rotation.adjacencyKey has nConnections entries', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.rotation.adjacencyKey.length).toBe(model.nConnections);
    expect(model.rotation.adjacencyKey[0]).toEqual(['D', 'T']);
});

test('fit: rotation.codes matches input codes', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.rotation.codes).toEqual(OPTS.codes);
});

test('fit: metaData has one entry per unit', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.metaData.length).toBe(model.nUnits);
    expect(model.metaData[0].Score).toBeDefined();
});

// ── fit: normed networks ──────────────────────────────────────────────────────

test('fit: lineWeights rows have L2 norm ≤ 1', () => {
    const model = ena.fit(ROWS, OPTS);
    for (let u = 0; u < model.nUnits; u++) {
        let norm = 0;
        for (let c = 0; c < model.nConnections; c++)
            norm += model.lineWeights[u * model.nConnections + c] ** 2;
        expect(Math.sqrt(norm)).toBeLessThanOrEqual(1 + 1e-10);
    }
});

// ── fit: raw networks differ from normed ─────────────────────────────────────

test('fit: connectionCounts values differ from lineWeights (raw vs normed)', () => {
    const model = ena.fit(ROWS, OPTS);
    // At least one value must differ — raw counts are integers, normed are fractions
    const rawArr    = Array.from(model.connectionCounts);
    const normedArr = Array.from(model.lineWeights);
    const allSame   = rawArr.every((v, i) => v === normedArr[i]);
    expect(allSame).toBe(false);
});

// ── ENAModel helpers ──────────────────────────────────────────────────────────

test('model.point(label) returns dims-length array', () => {
    const model = ena.fit(ROWS, OPTS);
    const p = model.point('U1');
    expect(p.length).toBe(2);
    expect(p.every(v => isFinite(v))).toBe(true);
});

test('model.network(label) returns nConnections-length array', () => {
    const model = ena.fit(ROWS, OPTS);
    const n = model.network('U2');
    expect(n.length).toBe(3);
});

test('model.point throws for unknown unit', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(() => model.point('GHOST')).toThrow();
});

// ── fit: means rotation ───────────────────────────────────────────────────────

test('fit with means rotation: rotation.columnNames[0] is MR1', () => {
    // U1 is index 0, U2 is index 1
    const model = ena.fit(ROWS, { ...OPTS, rotation: 'mean', groupA: [0], groupB: [1] });
    expect(model.rotation.columnNames[0]).toBe('MR1');
});

// ── error handling ────────────────────────────────────────────────────────────

test('fit throws when codes missing', () => {
    expect(() => ena.fit(ROWS, { units: ['UserName'], conversations: ['Condition'] }))
        .toThrow('opts.codes is required');
});

test('fit throws for means rotation without groups', () => {
    expect(() => ena.fit(ROWS, { ...OPTS, rotation: 'mean' }))
        .toThrow('opts.groupA and opts.groupB are required');
});

// ── stat helpers: confInts / outlierInts / compareGroups ─────────────────────

// 8 rows, 4 units (A1 A2 in group A; B1 B2 in group B), 3 codes
const ROWS_STAT = [
    { G: 'A', U: 'A1', C: 'C1', X: 1, Y: 1, Z: 0 },
    { G: 'A', U: 'A1', C: 'C1', X: 1, Y: 0, Z: 1 },
    { G: 'A', U: 'A2', C: 'C2', X: 0, Y: 1, Z: 1 },
    { G: 'A', U: 'A2', C: 'C2', X: 1, Y: 1, Z: 0 },
    { G: 'B', U: 'B1', C: 'C3', X: 0, Y: 0, Z: 1 },
    { G: 'B', U: 'B1', C: 'C3', X: 1, Y: 0, Z: 0 },
    { G: 'B', U: 'B2', C: 'C4', X: 0, Y: 1, Z: 0 },
    { G: 'B', U: 'B2', C: 'C4', X: 0, Y: 0, Z: 1 },
];
const OPTS_STAT = { codes: ['X', 'Y', 'Z'], units: ['U'], conversations: ['G', 'C'], dims: 2 };

test('confInts: output shape is { rows: dims, cols: 3 }', () => {
    const model = ena.fit(ROWS_STAT, OPTS_STAT);
    const ci = ena.confInts(model.points, model.nUnits, model.dims);
    expect(ci.rows).toBe(model.dims);
    expect(ci.cols).toBe(3);
    expect(ci.data.length).toBe(model.dims * 3);
});

test('confInts: lower <= mean <= upper for each dim', () => {
    const model = ena.fit(ROWS_STAT, OPTS_STAT);
    const ci = ena.confInts(model.points, model.nUnits, model.dims);
    for (let d = 0; d < model.dims; d++) {
        const mean  = ci.data[d * 3];
        const lower = ci.data[d * 3 + 1];
        const upper = ci.data[d * 3 + 2];
        expect(lower).toBeLessThanOrEqual(mean + 1e-12);
        expect(upper).toBeGreaterThanOrEqual(mean - 1e-12);
    }
});

test('confInts: all values are finite', () => {
    const model = ena.fit(ROWS_STAT, OPTS_STAT);
    const ci = ena.confInts(model.points, model.nUnits, model.dims);
    expect(ci.data.every(isFinite)).toBe(true);
});

test('confInts: wider CI at higher confidence level', () => {
    const model = ena.fit(ROWS_STAT, OPTS_STAT);
    const ci95 = ena.confInts(model.points, model.nUnits, model.dims, 0.95);
    const ci80 = ena.confInts(model.points, model.nUnits, model.dims, 0.80);
    // dim 0: upper - lower should be strictly wider at 0.95 than 0.80
    const width95 = ci95.data[2] - ci95.data[1];
    const width80 = ci80.data[2] - ci80.data[1];
    expect(width95).toBeGreaterThan(width80);
});

test('outlierInts: output shape is { rows: dims, cols: 2 }', () => {
    const model = ena.fit(ROWS_STAT, OPTS_STAT);
    const oi = ena.outlierInts(model.points, model.nUnits, model.dims);
    expect(oi.rows).toBe(model.dims);
    expect(oi.cols).toBe(2);
    expect(oi.data.length).toBe(model.dims * 2);
});

test('outlierInts: lower <= upper for each dim', () => {
    const model = ena.fit(ROWS_STAT, OPTS_STAT);
    const oi = ena.outlierInts(model.points, model.nUnits, model.dims);
    for (let d = 0; d < model.dims; d++) {
        expect(oi.data[d * 2]).toBeLessThanOrEqual(oi.data[d * 2 + 1] + 1e-12);
    }
});

test('outlierInts: larger iqrFactor gives wider bounds', () => {
    const model = ena.fit(ROWS_STAT, OPTS_STAT);
    const oi15 = ena.outlierInts(model.points, model.nUnits, model.dims, 1.5);
    const oi30 = ena.outlierInts(model.points, model.nUnits, model.dims, 3.0);
    // upper bound of dim 0 should be strictly wider at factor 3.0
    expect(Math.abs(oi30.data[1])).toBeGreaterThan(Math.abs(oi15.data[1]) - 1e-12);
});

test('compareGroups: result has expected fields', () => {
    const model = ena.fit(ROWS_STAT, OPTS_STAT);
    // A1, A2 = indices 0,1  (unitLabels are sorted by first appearance)
    const g1Idx = [0, 1];
    const g2Idx = [2, 3];
    const g1 = new Float64Array(g1Idx.flatMap(i =>
        Array.from(model.points.subarray(i * model.dims, (i + 1) * model.dims))));
    const g2 = new Float64Array(g2Idx.flatMap(i =>
        Array.from(model.points.subarray(i * model.dims, (i + 1) * model.dims))));
    const stats = ena.compareGroups(g1, g1Idx.length, g2, g2Idx.length, model.dims);
    expect(stats.n1).toBe(2);
    expect(stats.n2).toBe(2);
    for (const key of ['t', 'df', 'pvalue_t', 'cohens_d', 'U', 'pvalue_u', 'effect_r']) {
        expect(stats[key]).toHaveLength(model.dims);
    }
    expect(stats.means.rows).toBe(2);
    expect(stats.means.cols).toBe(model.dims);
});

test('compareGroups: p-values are in [0, 1]', () => {
    const model = ena.fit(ROWS_STAT, OPTS_STAT);
    const g1 = model.points.subarray(0, 2 * model.dims);
    const g2 = model.points.subarray(2 * model.dims);
    const stats = ena.compareGroups(g1, 2, g2, 2, model.dims);
    for (const p of [...stats.pvalue_t, ...stats.pvalue_u]) {
        expect(p).toBeGreaterThanOrEqual(0);
        expect(p).toBeLessThanOrEqual(1);
    }
});
