/**
 * Tests for PRIA (reduced-code search) in @qe-libs/rena-wasm.
 *
 * Full numeric parity against R PRIA::pria() is verified out-of-band on the
 * TADMUS dataset (removes AssessmentPrioritization, then +DefensiveOrders).
 * These tests guard the API surface, the 3-code floor, and the result bounds.
 */
import loadENA from '../src/index.js';

// 6 rows, 2 conversations, 2 units, 3 codes
const ROWS3 = [
    { Cond: 'A', Grp: 'G1', User: 'U1', D: 1, T: 1, P: 0 },
    { Cond: 'A', Grp: 'G1', User: 'U1', D: 1, T: 0, P: 1 },
    { Cond: 'A', Grp: 'G1', User: 'U2', D: 0, T: 1, P: 1 },
    { Cond: 'B', Grp: 'G1', User: 'U1', D: 1, T: 1, P: 0 },
    { Cond: 'B', Grp: 'G1', User: 'U2', D: 0, T: 0, P: 1 },
    { Cond: 'B', Grp: 'G1', User: 'U2', D: 1, T: 1, P: 1 },
];
const BASE3 = { codes: ['D', 'T', 'P'], units: ['User'], conversations: ['Cond', 'Grp'] };

// A larger synthetic set with 5 codes (A..E) so removal is possible.
function makeRows(n) {
    const rows = [];
    for (let i = 0; i < n; i++) {
        rows.push({
            Cond: i % 2 ? 'A' : 'B', Grp: 'G' + (i % 3), User: 'U' + (i % 4),
            A: i % 2, B: (i + 1) % 2, C: i % 3 === 0 ? 1 : 0,
            D: i % 5 === 0 ? 1 : 0, E: i % 7 === 0 ? 1 : 0,
        });
    }
    return rows;
}
const BASE5 = { codes: ['A', 'B', 'C', 'D', 'E'], units: ['User'], conversations: ['Cond', 'Grp'] };

let ena;
beforeAll(async () => { ena = await loadENA(); });

test('pria: 3-code model cannot be reduced (returns empty)', () => {
    const res = ena.pria(ROWS3, { ...BASE3, removeNum: 3, threshold: 0.95 });
    expect(res.removed).toEqual([]);
    expect(res.k).toBe(0);
});

test('pria: result stays within bounds and never drops below 3 codes', () => {
    const rows = makeRows(60);
    const res = ena.pria(rows, { ...BASE5, removeNum: 5, threshold: 0.5, window: 4 });
    // never remove more than m-3
    expect(res.removed.length).toBeLessThanOrEqual(BASE5.codes.length - 3);
    expect(res.k).toBe(res.removed.length);
    // every removed code is a real, distinct code
    for (const c of res.removed) expect(BASE5.codes).toContain(c);
    expect(new Set(res.removed).size).toBe(res.removed.length);
});

test('pria: an unreachable threshold (>1) removes nothing (correlations cannot exceed 1)', () => {
    const rows = makeRows(60);
    const res = ena.pria(rows, { ...BASE5, removeNum: 5, threshold: 1.5, window: 4 });
    expect(res.removed).toEqual([]);
    expect(res.k).toBe(0);
});
