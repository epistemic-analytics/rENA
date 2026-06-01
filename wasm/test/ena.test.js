/**
 * Integration tests for @qe-libs/rena-wasm.
 *
 * Uses a small synthetic dataset with two units, two conversations, and
 * three binary codes — enough to exercise the full pipeline without
 * depending on real RS.data.
 */
import loadENA from '../src/index.js';

// ── fixture ───────────────────────────────────────────────────────────────────

// 6 rows, 2 conversations (A, B), 2 units (U1, U2), 3 codes
const ROWS = [
    { Condition: 'A', GroupName: 'G1', UserName: 'U1', D: 1, T: 1, P: 0 },
    { Condition: 'A', GroupName: 'G1', UserName: 'U1', D: 1, T: 0, P: 1 },
    { Condition: 'A', GroupName: 'G1', UserName: 'U2', D: 0, T: 1, P: 1 },
    { Condition: 'B', GroupName: 'G1', UserName: 'U1', D: 1, T: 1, P: 0 },
    { Condition: 'B', GroupName: 'G1', UserName: 'U2', D: 0, T: 0, P: 1 },
    { Condition: 'B', GroupName: 'G1', UserName: 'U2', D: 1, T: 1, P: 1 },
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
    const { networks, nUnits, nConnections, unitLabels, connectionNames } =
        ena.accumulate(ROWS, OPTS);

    expect(nUnits).toBe(2);           // U1, U2
    expect(nConnections).toBe(3);     // choose_two(3) = 3
    expect(networks.length).toBe(6);  // 2 × 3
    expect(unitLabels).toEqual(['U1', 'U2']);
    expect(connectionNames).toEqual(['D & T', 'D & P', 'T & P']);
});

test('accumulate: all values are non-negative', () => {
    const { networks } = ena.accumulate(ROWS, OPTS);
    expect(Array.from(networks).every(v => v >= 0)).toBe(true);
});

// ── fit: output shapes ────────────────────────────────────────────────────────

test('fit: centroids shape is nUnits × dims', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.centroids.length).toBe(model.nUnits * model.dims);
    expect(model.nUnits).toBe(2);
    expect(model.dims).toBe(2);
});

test('fit: positions shape is nCodes × dims', () => {
    const model = ena.fit(ROWS, OPTS);
    // positions from node_positions: nCodes rows
    expect(model.positions.length).toBe(OPTS.codes.length * OPTS.dims);
});

test('fit: networks shape is nUnits × nConnections', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.networks.length).toBe(model.nUnits * model.nConnections);
    expect(model.nConnections).toBe(3);
});

test('fit: connectionNames matches codes pairs', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.connectionNames).toEqual(['D & T', 'D & P', 'T & P']);
});

test('fit: unitLabels in order of first appearance', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.unitLabels).toEqual(['U1', 'U2']);
});

test('fit: columnNames start with SVD for default rotation', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(model.columnNames[0]).toBe('SVD1');
    expect(model.columnNames[1]).toBe('SVD2');
});

// ── fit: normed networks ──────────────────────────────────────────────────────

test('fit: normed network rows have L2 norm ≤ 1', () => {
    const model = ena.fit(ROWS, OPTS);
    for (let u = 0; u < model.nUnits; u++) {
        let norm = 0;
        for (let c = 0; c < model.nConnections; c++)
            norm += model.networks[u * model.nConnections + c] ** 2;
        expect(Math.sqrt(norm)).toBeLessThanOrEqual(1 + 1e-10);
    }
});

// ── ENAModel helpers ──────────────────────────────────────────────────────────

test('model.centroid(label) returns dims-length array', () => {
    const model = ena.fit(ROWS, OPTS);
    const c = model.centroid('U1');
    expect(c.length).toBe(2);
    expect(c.every(v => isFinite(v))).toBe(true);
});

test('model.network(label) returns nConnections-length array', () => {
    const model = ena.fit(ROWS, OPTS);
    const n = model.network('U2');
    expect(n.length).toBe(3);
});

test('model.centroid throws for unknown unit', () => {
    const model = ena.fit(ROWS, OPTS);
    expect(() => model.centroid('GHOST')).toThrow();
});

// ── fit: means rotation ───────────────────────────────────────────────────────

test('fit with means rotation: first column is MR1', () => {
    // U1 is index 0, U2 is index 1
    const model = ena.fit(ROWS, { ...OPTS, rotation: 'mean', groupA: [0], groupB: [1] });
    expect(model.columnNames[0]).toBe('MR1');
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
