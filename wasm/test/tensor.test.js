/**
 * Tests for context-tensor accumulation in @qe-libs/rena-wasm.
 */
import loadENA from '../src/index.js';
import { inferFactorLevels, buildContextLookup, defaultTensor } from '../src/tensor.js';

// ── fixture ───────────────────────────────────────────────────────────────────

// 6 rows, 2 conversations, 2 units, 3 codes, 2 sender types
const ROWS = [
    { Condition: 'A', GroupName: 'G1', UserName: 'U1', Role: 'T', D: 1, T: 1, P: 0 },
    { Condition: 'A', GroupName: 'G1', UserName: 'U1', Role: 'S', D: 1, T: 0, P: 1 },
    { Condition: 'A', GroupName: 'G1', UserName: 'U2', Role: 'T', D: 0, T: 1, P: 1 },
    { Condition: 'B', GroupName: 'G1', UserName: 'U1', Role: 'S', D: 1, T: 1, P: 0 },
    { Condition: 'B', GroupName: 'G1', UserName: 'U2', Role: 'T', D: 0, T: 0, P: 1 },
    { Condition: 'B', GroupName: 'G1', UserName: 'U2', Role: 'S', D: 1, T: 1, P: 1 },
];

const BASE_OPTS = {
    codes:         ['D', 'T', 'P'],
    units:         ['UserName'],
    conversations: ['Condition', 'GroupName'],
};

// IS_DEFAULT tensor: weight=1, window=4
const SIMPLE_TENSOR = {
    dims:         [2],
    dimsSender:   [],
    dimsReceiver: [],
    dimsMode:     [],
    factors:      [],
    factorLevels: {},
    data:         Float64Array.of(1, 4),
};

// Two-factor tensor: Role × [weight/window], dims=[2,2]
// Role 'T'→0, 'S'→1; window=2 for all, weight=1 for all
const ROLE_TENSOR = {
    dims:         [2, 2],
    dimsSender:   [0],
    dimsReceiver: [],
    dimsMode:     [],
    factors:      ['Role'],
    factorLevels: { Role: { 'T': 0, 'S': 1 } },
    // flat col-major: [weight_T, weight_S, window_T, window_S]
    data:         Float64Array.of(1, 1, 2, 2),
};

let ena;
beforeAll(async () => { ena = await loadENA(); });

// ── inferFactorLevels ─────────────────────────────────────────────────────────

test('inferFactorLevels: assigns 0-based indices in order of first appearance', () => {
    const levels = inferFactorLevels(ROWS, ['Role']);
    expect(levels.Role['T']).toBe(0);
    expect(levels.Role['S']).toBe(1);
});

test('inferFactorLevels: handles multiple factors independently', () => {
    const levels = inferFactorLevels(ROWS, ['Role', 'Condition']);
    expect(Object.keys(levels.Role).length).toBe(2);
    expect(Object.keys(levels.Condition).length).toBe(2);
});

// ── buildContextLookup ────────────────────────────────────────────────────────

test('buildContextLookup: correct shape', () => {
    const rowIndices = [0, 1, 2];
    const levels = { Role: { 'T': 0, 'S': 1 } };
    const { contextLookup, clRows, clCols, times } =
        buildContextLookup(ROWS, rowIndices, ['Role'], levels);
    expect(clRows).toBe(3);
    expect(clCols).toBe(1);
    expect(contextLookup.length).toBe(3);
    expect(times.length).toBe(3);
});

test('buildContextLookup: maps values correctly', () => {
    const rowIndices = [0, 1];  // Role: T, S
    const levels = { Role: { 'T': 0, 'S': 1 } };
    const { contextLookup } = buildContextLookup(ROWS, rowIndices, ['Role'], levels);
    expect(contextLookup[0]).toBe(0);  // T → 0
    expect(contextLookup[1]).toBe(1);  // S → 1
});

test('buildContextLookup: times default to row indices', () => {
    const rowIndices = [0, 1, 2];
    const { times } = buildContextLookup(ROWS, rowIndices, [], {});
    expect(Array.from(times)).toEqual([0, 1, 2]);
});

// ── defaultTensor ─────────────────────────────────────────────────────────────

test('defaultTensor: produces IS_DEFAULT tensor with dims=[2]', () => {
    const t = defaultTensor(4);
    expect(t.dims).toEqual([2]);
    expect(t.data[0]).toBe(1);   // weight
    expect(t.data[1]).toBe(4);   // window
    expect(t.factors).toEqual([]);
});

test('defaultTensor: custom weight', () => {
    const t = defaultTensor(3, 0.5);
    expect(t.data[0]).toBe(0.5);
    expect(t.data[1]).toBe(3);
});

// ── accumulate with tensor ────────────────────────────────────────────────────

test('accumulate: IS_DEFAULT tensor gives same shape as simple window', () => {
    const simple = ena.accumulate(ROWS, { ...BASE_OPTS, window: 4 });
    const tensor = ena.accumulate(ROWS, { ...BASE_OPTS, tensor: SIMPLE_TENSOR });
    expect(tensor.nUnits).toBe(simple.nUnits);
    expect(tensor.nConnections).toBe(simple.nConnections);
    expect(tensor.connectionCounts.length).toBe(simple.connectionCounts.length);
});

// Value parity: a default tensor (no factors, weight 1, single window) must
// reduce to plain binary windowed accumulation — the invariant that regressed
// when accumulateTensor read the kernel's raw connection_counts instead of
// folding + binarizing the per-row counts the way tma does in R.
test('accumulate: IS_DEFAULT tensor VALUE-matches simple binary window', () => {
    const simple = ena.accumulate(ROWS, { ...BASE_OPTS, window: 4, binary: true });
    const tensor = ena.accumulate(ROWS, { ...BASE_OPTS, tensor: SIMPLE_TENSOR });
    expect(Array.from(tensor.connectionCounts))
        .toEqual(Array.from(simple.connectionCounts));
});

// aggregate_row_connections mirrors tma's R aggregation of apply_tensor_unit's
// row_connection_counts (as.unordered + colSums.ena.matrix(binary)).  Golden
// values hand-verified against libqe::apply_tensor in R on a dense case where a
// response row sees the same ground code three times.
test('aggregate_row_connections: fold + per-row binarize + sum (unordered)', () => {
    // 4 response rows, 3 codes → p²=9 columns (row-major, directed per row).
    const rowConn = [
        1, 0, 0, 0, 0, 0, 0, 0, 0,
        3, 0, 0, 0, 0, 0, 0, 0, 0,
        5, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 3, 3, 3, 1, 1, 3, 1, 1,
    ];
    const bin = ena.qe.aggregate_row_connections(rowConn, 4, 9, 3, false, true);
    const raw = ena.qe.aggregate_row_connections(rowConn, 4, 9, 3, false, false);
    const ord = ena.qe.aggregate_row_connections(rowConn, 4, 9, 3, true, false);
    expect(Array.from(bin)).toEqual([1, 1, 1]);            // per-row binarized
    expect(Array.from(raw)).toEqual([6, 6, 2]);            // folded, not binarized
    expect(Array.from(ord)).toEqual([9, 3, 3, 3, 1, 1, 3, 1, 1]);  // directed colSums
});

test('accumulate: role tensor returns correct shape', () => {
    const result = ena.accumulate(ROWS, { ...BASE_OPTS, tensor: ROLE_TENSOR });
    expect(result.nUnits).toBe(2);
    expect(result.nConnections).toBe(3);  // choose_two(3), unordered
    expect(result.connectionCounts.length).toBe(6);
});

test('accumulate: ordered tensor gives n² connections', () => {
    const result = ena.accumulate(ROWS, {
        ...BASE_OPTS,
        ordered: true,
        tensor: ROLE_TENSOR,
    });
    expect(result.nConnections).toBe(9);  // 3² = 9
    expect(result.connectionCounts.length).toBe(2 * 9);
});

test('accumulate: tensor networks are non-negative', () => {
    const { connectionCounts } = ena.accumulate(ROWS, { ...BASE_OPTS, tensor: ROLE_TENSOR });
    expect(Array.from(connectionCounts).every(v => v >= 0)).toBe(true);
});

// ── fit with tensor ───────────────────────────────────────────────────────────

test('fit: tensor path returns ENAModel with correct shape', () => {
    const model = ena.fit(ROWS, { ...BASE_OPTS, tensor: ROLE_TENSOR, dims: 2 });
    expect(model.nUnits).toBe(2);
    expect(model.nConnections).toBe(3);
    expect(model.points.length).toBe(2 * 2);
    expect(model.rotation.nodes.length).toBe(3 * 2);  // nCodes × dims
});

test('fit: tensor model has finite point values', () => {
    const model = ena.fit(ROWS, { ...BASE_OPTS, tensor: ROLE_TENSOR });
    expect(Array.from(model.points).every(v => isFinite(v))).toBe(true);
});

test('fit: infers factorLevels when not provided', () => {
    const tensorNoLevels = { ...ROLE_TENSOR, factorLevels: undefined };
    expect(() => ena.fit(ROWS, { ...BASE_OPTS, tensor: tensorNoLevels })).not.toThrow();
});
