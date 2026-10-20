/**
 * fit({ selfWeight }) — the ordered node optimization's self-connection
 * weight (libena directed_node_weights): 2 (default) = a node's row + column
 * sum (Zhiqiang Cai's 2021 rule), 1 = once. = R's model(self_weight =).
 */
import loadENA from '../src/index.js';

// Codes repeat across lines, so the ordered networks have self-connections.
const ROWS = [
    { C: 'A', U: 'U1', D: 1, T: 1, P: 0 },
    { C: 'A', U: 'U1', D: 1, T: 0, P: 1 },
    { C: 'A', U: 'U2', D: 0, T: 1, P: 1 },
    { C: 'A', U: 'U2', D: 1, T: 1, P: 0 },
    { C: 'B', U: 'U3', D: 1, T: 1, P: 0 },
    { C: 'B', U: 'U3', D: 0, T: 1, P: 1 },
    { C: 'B', U: 'U4', D: 1, T: 0, P: 1 },
    { C: 'B', U: 'U4', D: 1, T: 0, P: 0 },
];
const OPTS = { codes: ['D', 'T', 'P'], units: ['U'], conversations: ['C'], window: 4, dims: 2, ordered: true };

let ena;
beforeAll(async () => { ena = await loadENA(); });

test('ordered fit records selfWeight (default 2)', () => {
    expect(ena.fit(ROWS, OPTS).rotation.selfWeight).toBe(2);
    expect(ena.fit(ROWS, { ...OPTS, selfWeight: 1 }).rotation.selfWeight).toBe(1);
    expect(ena.fit(ROWS, { ...OPTS, ordered: false }).rotation.selfWeight).toBeNull();
});

test('selfWeight changes nodes and centroids, not points', () => {
    const two = ena.fit(ROWS, OPTS);
    const one = ena.fit(ROWS, { ...OPTS, selfWeight: 1 });
    expect(Array.from(one.points)).toEqual(Array.from(two.points));
    const diff = Math.max(...Array.from(two.rotation.nodes, (v, i) => Math.abs(v - one.rotation.nodes[i])));
    expect(diff).toBeGreaterThan(1e-6);
});

test('unordered models ignore selfWeight', () => {
    const a = ena.fit(ROWS, { ...OPTS, ordered: false });
    const b = ena.fit(ROWS, { ...OPTS, ordered: false, selfWeight: 1 });
    expect(Array.from(a.rotation.nodes)).toEqual(Array.from(b.rotation.nodes));
});
