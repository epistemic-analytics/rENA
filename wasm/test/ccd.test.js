/**
 * Tests for Cross-Covariance Decay (CCD) window-size estimation
 * (port of R's ena.ccd / ena.ccd.window, backed by the shared libqe kernel
 * qe::ccd_window). Verified against R on RS.data (window_size = 6, peak_lag = 1;
 * curves agree to ~1e-16).
 */
import loadENA from '../src/index.js';

describe('ccd / ccdWindow', () => {
    let ena;
    beforeAll(async () => { ena = await loadENA(); });

    // Deterministic fixture: 2 conversations × 40 rows, code B tends to follow
    // code A at lag 1 (with decay), so the corrected covariance peaks at lag 1.
    let seed = 7;
    const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
    const rows = [];
    for (const conv of ['C1', 'C2']) {
        let prevA = 0;
        for (let i = 0; i < 40; i++) {
            const A = rnd() < 0.4 ? 1 : 0;
            const B = (prevA === 1 && rnd() < 0.8) ? 1 : (rnd() < 0.15 ? 1 : 0);
            const C = rnd() < 0.3 ? 1 : 0;
            rows.push({ Convo: conv, A, B, C });
            prevA = A;
        }
    }
    const opts = { codes: ['A', 'B', 'C'], conversations: ['Convo'], maxWindow: 15, minOverlap: 5 };

    test('estimates a plausible window and peak lag', () => {
        const r = ena.ccd(rows, opts);
        expect(r.window_size).toBe(2);
        expect(r.peak_lag).toBe(1);
    });

    test('curve arrays have length maxWindow + 1 and cover lags 0..maxWindow', () => {
        const r = ena.ccd(rows, opts);
        for (const key of ['lag', 'frob', 'frob_sq_unbiased', 'frob_unbiased_signed', 'total_weight']) {
            expect(r[key].length).toBe(opts.maxWindow + 1);
        }
        expect(r.lag[0]).toBe(0);
        expect(r.lag[r.lag.length - 1]).toBe(opts.maxWindow);
    });

    test('ccdWindow returns just the window size', () => {
        expect(ena.ccdWindow(rows, opts)).toBe(2);
    });

    test('window size is within [1, maxWindow]', () => {
        const r = ena.ccd(rows, opts);
        expect(r.window_size).toBeGreaterThanOrEqual(1);
        expect(r.window_size).toBeLessThanOrEqual(opts.maxWindow);
    });

    test('conversations shorter than minOverlap default to window 1', () => {
        const tiny = [
            { Convo: 'C1', A: 1, B: 0, C: 1 },
            { Convo: 'C1', A: 0, B: 1, C: 0 },
            { Convo: 'C1', A: 1, B: 1, C: 1 },
        ];
        const r = ena.ccd(tiny, { codes: ['A', 'B', 'C'], conversations: ['Convo'], maxWindow: 15, minOverlap: 10 });
        expect(r.window_size).toBe(1);
        expect(r.peak_lag).toBe(0);
    });

    test('missing codes/conversations throws', () => {
        expect(() => ena.ccd(rows, { conversations: ['Convo'] })).toThrow(/codes/);
        expect(() => ena.ccd(rows, { codes: ['A', 'B', 'C'] })).toThrow(/conversations/);
    });
});
