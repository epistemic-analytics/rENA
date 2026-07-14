/**
 * Tests for window-size tuning (port of R's ena.tune.window.size) and the
 * distance-space correlation helper (ena_space_dist_corr).
 */
import loadENA from '../src/index.js';
import { spaceDistCorr } from '../src/pipeline.js';

// ── spaceDistCorr (pure, no WASM) ─────────────────────────────────────────────

describe('spaceDistCorr', () => {
    const P = new Float64Array([0, 0, 1, 2, 3, 1, 2, 4, 5, 0, 1, 1, 4, 3, 2, 2]); // 8 × 2

    test('identical spaces correlate at 1', () => {
        expect(spaceDistCorr(P, P, 8, 2)).toBeCloseTo(1.0, 10);
    });

    test('reflection (axis flip) is invariant', () => {
        const flip = new Float64Array(P.length);
        for (let i = 0; i < 8; i++) { flip[i * 2] = P[i * 2 + 1]; flip[i * 2 + 1] = P[i * 2]; }
        expect(spaceDistCorr(P, flip, 8, 2)).toBeCloseTo(1.0, 10);
    });

    test('rotation is invariant', () => {
        const theta = 0.7, c = Math.cos(theta), s = Math.sin(theta);
        const rot = new Float64Array(P.length);
        for (let i = 0; i < 8; i++) {
            const x = P[i * 2], y = P[i * 2 + 1];
            rot[i * 2]     = c * x - s * y;
            rot[i * 2 + 1] = s * x + c * y;
        }
        expect(spaceDistCorr(P, rot, 8, 2)).toBeCloseTo(1.0, 10);
    });

    test('zero rows throws', () => {
        expect(() => spaceDistCorr(P, P, 0, 2)).toThrow();
    });

    test('sampled path runs (tiny maxSampleSize)', () => {
        expect(spaceDistCorr(P, P, 8, 2, 4)).toBeCloseTo(1.0, 10);
    });
});

// ── tuneWindowSize (full pipeline) ────────────────────────────────────────────

describe('tuneWindowSize', () => {
    let ena;
    beforeAll(async () => { ena = await loadENA(); });

    // Deterministic-ish synthetic dataset: 8 units, 4 conversations, 4 codes.
    let seed = 1;
    const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
    const rows = [];
    for (let i = 0; i < 160; i++) rows.push({
        UserName: `U${i % 8}`, Condition: `C${i % 4}`,
        D: rnd() < 0.5 ? 1 : 0, T: rnd() < 0.5 ? 1 : 0,
        P: rnd() < 0.5 ? 1 : 0, Q: rnd() < 0.5 ? 1 : 0,
    });
    const opts = {
        codes: ['D', 'T', 'P', 'Q'],
        units: ['UserName'],
        conversations: ['Condition'],
        window: 4,
    };

    test('accumulate stores _call for tuning', () => {
        const accum = ena.accumulate(rows, opts);
        expect(accum._call).toBeDefined();
        expect(accum._call.window).toBe(4);
        expect(accum._call.codes).toEqual(['D', 'T', 'P', 'Q']);
    });

    test('returns accumulation rebuilt at selected window', () => {
        const accum = ena.accumulate(rows, opts);
        const tuned = ena.tuneWindowSize(accum, { minSize: 1, maxSize: 6, cutoff: 0.95 });
        expect(tuned._call.window).toBeGreaterThanOrEqual(1);
        expect(tuned._call.window).toBeLessThanOrEqual(6);
        expect(tuned.nUnits).toBe(8);
        expect(tuned.connectionCounts.length).toBe(8 * tuned.nConnections);
    });

    test('throws without a stored _call', () => {
        expect(() => ena.tuneWindowSize({}, {})).toThrow();
    });

    test('throws when the range has fewer than two windows', () => {
        const accum = ena.accumulate(rows, opts);
        expect(() => ena.tuneWindowSize(accum, { minSize: 3, maxSize: 3 })).toThrow();
    });
});
