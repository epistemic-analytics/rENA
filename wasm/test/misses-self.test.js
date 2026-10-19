/**
 * Missed co-occurrences and self-connections from accumulate() / fit(),
 * accumulated by libtma's accumulate_unit_networks (= tma's accumulate()).
 * Values match R tma::accumulate() on rs.data (checked when wired); here the
 * structure and internal consistency are pinned.
 */
import loadENA from '../src/index.js';

const ROWS = [
    { C: 'A', U: 'U1', D: 1, T: 1, P: 0 },
    { C: 'A', U: 'U1', D: 1, T: 0, P: 1 },
    { C: 'A', U: 'U2', D: 0, T: 1, P: 1 },
    { C: 'B', U: 'U1', D: 1, T: 1, P: 0 },
    { C: 'B', U: 'U2', D: 0, T: 0, P: 1 },
    { C: 'B', U: 'U2', D: 1, T: 1, P: 1 },
];
const OPTS = { codes: ['D', 'T', 'P'], units: ['U'], conversations: ['C'], window: 4, dims: 2 };

let ena;
beforeAll(async () => { ena = await loadENA(); });

test('accumulate: self-connections and misses on by default', () => {
    const a = ena.accumulate(ROWS, OPTS);
    expect(a.selfConnectionCounts.length).toBe(a.nUnits * 3);
    expect(a.missCounts.length).toBe(a.nUnits * a.nConnections);
    expect(a.selfMissCounts.length).toBe(a.nUnits * 3);
});

test('misses: false leaves them out; connections unchanged', () => {
    const on  = ena.accumulate(ROWS, OPTS);
    const off = ena.accumulate(ROWS, { ...OPTS, misses: false });
    expect(off.missCounts).toBeNull();
    expect(off.selfMissCounts).toBeNull();
    expect(Array.from(off.connectionCounts)).toEqual(Array.from(on.connectionCounts));
    expect(Array.from(off.rowConnectionCounts)).toEqual(Array.from(on.rowConnectionCounts));
    expect(Array.from(off.selfConnectionCounts)).toEqual(Array.from(on.selfConnectionCounts));
});

test('ordered self-connections equal the diagonal of the ordered networks', () => {
    const o = ena.accumulate(ROWS, { ...OPTS, ordered: true, weightModel: 'product' });
    const p = 3;
    for (let u = 0; u < o.nUnits; u++)
        for (let i = 0; i < p; i++)
            expect(o.selfConnectionCounts[u * p + i])
                .toBe(o.connectionCounts[u * o.nConnections + i * p + i]);
});

test('unordered and ordered models share the same self-connections', () => {
    const w = { weightModel: 'product' };
    const u = ena.accumulate(ROWS, { ...OPTS, ...w });
    const o = ena.accumulate(ROWS, { ...OPTS, ...w, ordered: true });
    expect(Array.from(u.selfConnectionCounts)).toEqual(Array.from(o.selfConnectionCounts));
});

test('fit keeps them on the model and they do not change it', () => {
    const on  = ena.fit(ROWS, OPTS);
    const off = ena.fit(ROWS, { ...OPTS, misses: false });
    expect(on.selfConnectionCounts.length).toBe(on.nUnits * 3);
    expect(on.missCounts.length).toBe(on.nUnits * on.nConnections);
    expect(off.missCounts).toBeNull();
    expect(Array.from(on.points)).toEqual(Array.from(off.points));
    expect(Array.from(on.lineWeights)).toEqual(Array.from(off.lineWeights));
});
