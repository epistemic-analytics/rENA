/**
 * Integration tests for @qe-libs/rena-wasm.
 *
 * Uses a small synthetic dataset with two units, two conversations, and
 * three binary codes — enough to exercise the full pipeline without
 * depending on real RS.data.
 *
 * Field names match the R ena.set structure:
 *   model.connectionCounts      = R set$connection.counts (raw)
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
    const { connectionCounts, nUnits, nConnections, unitLabels, connectionNames } =
        ena.accumulate(ROWS, OPTS);

    expect(nUnits).toBe(2);                     // U1, U2
    expect(nConnections).toBe(3);               // choose_two(3) = 3
    expect(connectionCounts.length).toBe(6);    // 2 × 3
    expect(unitLabels).toEqual(['U1', 'U2']);
    expect(connectionNames).toEqual(['D & T', 'D & P', 'T & P']);
});

test('accumulate: all values are non-negative', () => {
    const { connectionCounts } = ena.accumulate(ROWS, OPTS);
    expect(Array.from(connectionCounts).every(v => v >= 0)).toBe(true);
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
