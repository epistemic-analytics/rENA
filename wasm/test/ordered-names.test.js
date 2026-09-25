/**
 * Ordered (ONA) connection names and adjacency key follow R: column j*n + i
 * is ground codes[i] → response codes[j], named "codes[i] & codes[j]".
 *
 * R reference (rENA 0.4.8):
 *   d <- data.frame(U = "u1", C = "c1", A = c(1, 0), B = c(0, 1), Z = 0)
 *   acc <- accumulate(d, "U", c("A","B","Z"), "C", default_window = 2, ordered = TRUE)
 *   as.matrix(acc$connection.counts)
 *   #  A & A B & A Z & A A & B B & B Z & B A & Z B & Z Z & Z
 *   #      0     0     0     1     0     0     0     0     0
 */
import loadENA from '../src/index.js';

const CODES = ['A', 'B', 'Z'];
const R_NAMES = ['A & A', 'B & A', 'Z & A', 'A & B', 'B & B', 'Z & B', 'A & Z', 'B & Z', 'Z & Z'];
const OPTS = { codes: CODES, units: ['U'], conversations: ['C'], window: 2, ordered: true };

let ena;
beforeAll(async () => { ena = await loadENA(); });

// A on the first line, B on the second: one ground A → response B connection.
const AB = [{ U: 'u1', C: 'c1', A: '1', B: '0', Z: '0' },
            { U: 'u1', C: 'c1', A: '0', B: '1', Z: '0' }];

test('accumulate() names ordered columns as R does', () => {
    const acc = ena.accumulate(AB, OPTS);
    expect(acc.connectionNames).toEqual(R_NAMES);
    expect(Array.from(acc.connectionCounts)).toEqual([0, 0, 0, 1, 0, 0, 0, 0, 0]);
    expect(acc.connectionNames[acc.connectionCounts.indexOf(1)]).toBe('A & B');
});

test('fit() connection names and adjacency key are ground → response', () => {
    // A second unit so the model has variance to rotate.
    const rows = AB.concat([{ U: 'u2', C: 'c2', A: '0', B: '1', Z: '0' },
                            { U: 'u2', C: 'c2', A: '1', B: '0', Z: '0' }]);
    const m = ena.fit(rows, { ...OPTS, dims: 2 });
    expect(m.nConnections).toBe(9);
    expect(m.connectionNames).toEqual(R_NAMES);
    expect(m.rotation.adjacencyKey).toEqual(R_NAMES.map(n => n.split(' & ')));
});

test('unordered names and key are unchanged', () => {
    const m = ena.accumulate(AB, { ...OPTS, ordered: false });
    expect(m.connectionNames).toEqual(['A & B', 'A & Z', 'B & Z']);
});
