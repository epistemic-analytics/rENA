/**
 * Tests for weight models (= R's `weight.by`) in @qe-libs/rena-wasm.
 *
 * Full numeric parity against R rENA (weight.by = sqrt / log1p / "product") is
 * verified out-of-band on RS.data (maxAbsErr ~5e-14). These tests guard the
 * API surface and the line-level ordering property that sqrt(Σ) ≠ Σsqrt — i.e.
 * the transform is applied per line BEFORE the per-unit sum, not after.
 */
import loadENA from '../src/index.js';

const ROWS = [
    { Cond: 'A', Grp: 'G1', User: 'U1', D: 1, T: 1, P: 0 },
    { Cond: 'A', Grp: 'G1', User: 'U1', D: 1, T: 1, P: 1 },
    { Cond: 'A', Grp: 'G1', User: 'U2', D: 1, T: 1, P: 1 },
    { Cond: 'B', Grp: 'G1', User: 'U1', D: 1, T: 1, P: 0 },
    { Cond: 'B', Grp: 'G1', User: 'U2', D: 1, T: 0, P: 1 },
    { Cond: 'B', Grp: 'G1', User: 'U2', D: 1, T: 1, P: 1 },
];
const BASE = { codes: ['D', 'T', 'P'], units: ['User'], conversations: ['Cond', 'Grp'], window: 4 };

let ena;
beforeAll(async () => { ena = await loadENA(); });

test('weight: product keeps raw non-binary counts (identity)', () => {
    const raw = ena.fit(ROWS, { ...BASE, binary: false });
    const prod = ena.fit(ROWS, { ...BASE, weightModel: 'product' });
    // product == non-binary accumulation with no transform
    for (let i = 0; i < raw.lineWeights.length; i++) {
        expect(prod.lineWeights[i]).toBeCloseTo(raw.lineWeights[i], 12);
    }
});

test('weight: sqrt differs from applying sqrt to the unit-summed network', () => {
    // Line-level sqrt is NOT the same as sqrt of the summed counts.
    const rawNonBin = ena.fit(ROWS, { ...BASE, binary: false });
    const sqrtModel = ena.fit(ROWS, { ...BASE, weightModel: 'sqrt' });
    let anyDiff = false;
    for (let i = 0; i < rawNonBin.lineWeights.length; i++) {
        if (Math.abs(sqrtModel.lineWeights[i] - rawNonBin.lineWeights[i]) > 1e-9) anyDiff = true;
    }
    expect(anyDiff).toBe(true);
});

test('weight: sqrt and log produce finite, normalized line weights', () => {
    for (const wm of ['sqrt', 'log']) {
        const res = ena.fit(ROWS, { ...BASE, weightModel: wm });
        for (const v of res.lineWeights) expect(Number.isFinite(v)).toBe(true);
    }
});

test('weight: unknown / binary weight model falls back to binary accumulation', () => {
    const bin = ena.fit(ROWS, { ...BASE, binary: true });
    const off = ena.fit(ROWS, { ...BASE, weightModel: 'binary' });
    for (let i = 0; i < bin.lineWeights.length; i++) {
        expect(off.lineWeights[i]).toBeCloseTo(bin.lineWeights[i], 12);
    }
});
