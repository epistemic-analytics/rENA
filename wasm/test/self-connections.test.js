/**
 * Unordered models with self-connection columns: accumulate / fit
 * ({ selfConnections: true }) — A & A, A & B, B & B, ... columns, nodes from
 * libena's key-driven weighting (self counted selfWeight times). Matches R
 * rENA::accumulate(self_connections = TRUE) |> model() (checked on rs.data
 * when wired: line weights, points and nodes to ~1e-14).
 */
import loadENA from '../src/index.js';

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
const OPTS = { codes: ['D', 'T', 'P'], units: ['U'], conversations: ['C'], window: 4, dims: 2 };
const SELF = { ...OPTS, selfConnections: true };

let ena;
beforeAll(async () => { ena = await loadENA(); });

test('accumulate: self columns in the A & A, A & B, B & B, ... layout', () => {
    const a = ena.accumulate(ROWS, { ...SELF, weightModel: 'product' });
    expect(a.nConnections).toBe(6);
    expect(a.connectionNames).toEqual(['D & D', 'D & T', 'T & T', 'D & P', 'T & P', 'P & P']);
    const selfCols = [0, 2, 5];
    for (let u = 0; u < a.nUnits; u++)
        selfCols.forEach((k, i) => expect(a.connectionCounts[u * 6 + k]).toBeCloseTo(a.selfConnectionCounts[u * 3 + i], 12));
    // without it: unchanged layout
    expect(ena.accumulate(ROWS, OPTS).connectionNames).toEqual(['D & T', 'D & P', 'T & P']);
});

test('fit: key, nodes from the key-driven weighting, centroids consistent', () => {
    const m = ena.fit(ROWS, SELF);
    expect(m.nConnections).toBe(6);
    expect(m.rotation.adjacencyKey).toEqual([['D', 'D'], ['D', 'T'], ['T', 'T'], ['D', 'P'], ['T', 'P'], ['P', 'P']]);
    const key = ena.qe.undirected_connection_key(3, true);
    const ref = ena.qe.node_positions_by_key(m.lineWeights, m.nUnits, 6, m.points, m.nUnits, 2, 2,
                                             key.from, key.to, 3, 2);
    Array.from(ref.nodes.data).forEach((v, i) => expect(m.rotation.nodes[i]).toBeCloseTo(v, 10));
    const w = ena.qe.node_weights_by_key(m.lineWeights, m.nUnits, 6, key.from, key.to, 3, 2);
    const moved = ena.moveNodesToUnitCircle(m, { dims: [0, 1] });
    for (let u = 0; u < m.nUnits; u++)
        for (let d = 0; d < 2; d++) {
            let c = 0;
            for (let i = 0; i < 3; i++) c += w.data[u * 3 + i] * moved.rotation.nodes[i * 2 + d];
            expect(moved.model.centroids[u * 2 + d]).toBeCloseTo(c, 10);
        }
});

test('selfWeight weighs the self columns; ordered models ignore selfConnections', () => {
    const two = ena.fit(ROWS, SELF);
    const one = ena.fit(ROWS, { ...SELF, selfWeight: 1 });
    expect(Array.from(one.points)).toEqual(Array.from(two.points));
    const diff = Math.max(...Array.from(two.rotation.nodes, (v, i) => Math.abs(v - one.rotation.nodes[i])));
    expect(diff).toBeGreaterThan(1e-6);
    const o1 = ena.fit(ROWS, { ...SELF, ordered: true });
    const o0 = ena.fit(ROWS, { ...OPTS, ordered: true });
    expect(o1.nConnections).toBe(9);
    expect(Array.from(o1.rotation.nodes)).toEqual(Array.from(o0.rotation.nodes));
});
