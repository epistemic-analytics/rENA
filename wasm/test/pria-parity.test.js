/**
 * PRIA parity with R PRIA::pria() on RS.data, and option forwarding.
 *
 * Expected values come from R (PRIA 0.1.3 + rENA 0.4.5): ena.make.set() on
 * ena.accumulate.data(window.size.back = 4), units Condition + UserName,
 * conversations Condition + GroupName, then pria(set, remove.num = 3,
 * threshold); variance is get_pria_scores_2Ds(set, removed)$vr1
 * (= reduced.set$model$variance[1]). Means rotation groups are FirstGame vs
 * SecondGame; GMR regresses on Condition.
 */
import fs   from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import loadENA from '../src/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const EXTDATA   = path.resolve(__dirname, '../../inst/extdata');

function parseCSVRow(line) {
    const result = [];
    let current  = '';
    let inQuotes = false;
    for (let i = 0; i < line.length; i++) {
        const ch = line[i];
        if (ch === '\r') continue;
        if (ch === '"') {
            if (inQuotes && line[i + 1] === '"') { current += '"'; i++; }
            else inQuotes = !inQuotes;
        } else if (ch === ',' && !inQuotes) {
            result.push(current);
            current = '';
        } else {
            current += ch;
        }
    }
    result.push(current);
    return result;
}

function parseCSV(text) {
    const lines   = text.split('\n').filter(l => l.trim().replace(/\r/g, '') !== '');
    const headers = parseCSVRow(lines[0]);
    return lines.slice(1).map(line => {
        const values = parseCSVRow(line);
        return Object.fromEntries(headers.map((h, i) => [h, values[i] ?? '']));
    });
}

const CODES = ['Data', 'Technical Constraints', 'Performance Parameters',
               'Client and Consultant Requests', 'Design Reasoning', 'Collaboration'];
const BASE  = { codes: CODES, units: ['Condition', 'UserName'],
                conversations: ['Condition', 'GroupName'], window: 4, removeNum: 3 };

let ena, rows, rotations;

beforeAll(async () => {
    ena  = await loadENA();
    rows = parseCSV(fs.readFileSync(path.join(EXTDATA, 'rs.data.csv'), 'utf8'));

    // Unit order = first appearance, as parseData() builds it.
    const seen = new Map();
    for (const r of rows) {
        const key = BASE.units.map(c => String(r[c])).join('__');
        if (!seen.has(key)) seen.set(key, r);
    }
    const cond   = [...seen.values()].map(r => String(r.Condition));
    const levels = [...new Set(cond)];
    const n      = cond.length;
    const groupA = [], groupB = [];
    cond.forEach((v, i) => (v === 'FirstGame' ? groupA : groupB).push(i));
    const xModelMatrix = new Float64Array(n * (levels.length - 1));
    cond.forEach((v, u) => { const l = levels.indexOf(v); if (l > 0) xModelMatrix[u + l - 1] = 1; });
    const gParams = {
        xModelMatrix, xmRows: n, xmCols: levels.length - 1,
        xTarget: Float64Array.from(cond.map(v => levels.indexOf(v))),
        x1Cols: Int32Array.from([0]), xCategorical: true, xNGroups: levels.length,
        xSubset: Int32Array.from(cond.map((_, i) => i)), hasY: false,
    };
    rotations = {
        svd:  {},
        mean: { rotation: 'mean', groupA, groupB },
        gmr:  { rotation: 'generalized', gParams },
    };
});

describe('pria matches R PRIA::pria on RS.data', () => {
    const R = [
        // threshold, rotation, removed codes, reduced dim-1 variance
        [0.95, 'svd',  ['Data'], 0.3831014662],
        [0.95, 'mean', ['Data'], 0.3700976608],
        [0.95, 'gmr',  ['Data'], 0.3700976608],
        [0.90, 'svd',  ['Data', 'Client and Consultant Requests'], 0.4737718777],
        [0.90, 'mean', ['Data', 'Client and Consultant Requests'], 0.4589809744],
        [0.90, 'gmr',  ['Data', 'Client and Consultant Requests'], 0.4589809744],
    ];
    for (const [threshold, rot, removed, variance] of R) {
        test(`threshold ${threshold}, ${rot}`, () => {
            const res = ena.pria(rows, { ...BASE, threshold, ...rotations[rot] });
            expect(res.removed).toEqual(removed);
            expect(res.k).toBe(removed.length);
            expect(res.variance).toBeCloseTo(variance, 9);
        });
    }
});

describe('pria scores the model fit() would build', () => {
    // Reduced-model dim-1 variance of fit() on the retained codes only.
    const reducedVariance = (removed, opts) => {
        const kept = CODES.filter(c => !removed.includes(c));
        const m = ena.fit(rows, { ...BASE, ...opts, codes: kept,
                                  dims: kept.length * (kept.length - 1) / 2 });
        return m.model.variance[0];
    };

    test('weightModel is applied to the full and reduced models', () => {
        const res = ena.pria(rows, { ...BASE, threshold: 0.95, weightModel: 'sqrt' });
        expect(res.k).toBeGreaterThan(0);
        expect(res.variance).toBeCloseTo(reducedVariance(res.removed, { weightModel: 'sqrt' }), 10);
        const unweighted = ena.pria(rows, { ...BASE, threshold: 0.95 });
        expect(res.variance).not.toBeCloseTo(unweighted.variance, 6);
    });

    test("the caller's codeMask is kept, not replaced", () => {
        // Mask one connection between two codes that PRIA will not remove.
        const a = CODES.indexOf('Technical Constraints'), b = CODES.indexOf('Performance Parameters');
        const codeMask = CODES.map((_, i) => CODES.map((_, j) =>
            ((i === a && j === b) || (i === b && j === a)) ? 0 : 1));
        const res = ena.pria(rows, { ...BASE, threshold: 0.95, codeMask });
        expect(res.k).toBeGreaterThan(0);
        expect(res.removed).not.toContain('Technical Constraints');
        expect(res.removed).not.toContain('Performance Parameters');

        const kept = CODES.filter(c => !res.removed.includes(c));
        const ka = kept.indexOf('Technical Constraints'), kb = kept.indexOf('Performance Parameters');
        const keptMask = kept.map((_, i) => kept.map((_, j) =>
            ((i === ka && j === kb) || (i === kb && j === ka)) ? 0 : 1));
        expect(res.variance).toBeCloseTo(reducedVariance(res.removed, { codeMask: keptMask }), 10);
        const unmasked = ena.pria(rows, { ...BASE, threshold: 0.95 });
        expect(res.variance).not.toBeCloseTo(unmasked.variance, 6);
    });
});

// ── ONA (ordered) and transmodal (TMA) models ────────────────────────────────
// R reference: rENA's piped pipeline accumulate() |> sphere_norm() |> center()
// |> rotate() |> project() |> optimize() (directed node positions for ordered
// sets), with PRIA::pria(set, remove.num = 3, threshold, rebuild = <same
// pipeline>) and the accumulation's adjacency key kept on the set, as
// rENA-api's ena.generate did. The TMA tensor: sender factor GameHalf,
// "First" weight 0.5 / window 2, "Second" weight 1 / window 4. (In R,
// GameHalf is pre-encoded as First = 1, Second = 2: tma's accumulate()
// re-encodes character-valued tensor columns within each unit's context.)
describe('pria matches R PRIA::pria for ONA and TMA models', () => {
    const TMA_TENSOR = {
        dims: [2, 2], dimsSender: [0], dimsReceiver: [], dimsMode: [],
        factors: ['GameHalf'], factorLevels: { GameHalf: { First: 0, Second: 1 } },
        data: Float64Array.from([0.5, 1, 2, 4]),
    };
    const ONA_REMOVED = ['Client and Consultant Requests', 'Collaboration'];
    const R = [
        // model, rotation, removed codes, reduced dim-1 variance (same at 0.95 and 0.90)
        ['ona', 'svd',  ONA_REMOVED, 0.2904114172],
        ['ona', 'mean', ONA_REMOVED, 0.1883372501],
        ['tma', 'svd',  ['Data'],    0.3632817359],
        ['tma', 'mean', ['Data'],    0.3435685191],
    ];
    for (const threshold of [0.95, 0.90]) {
        for (const [model, rot, removed, variance] of R) {
            test(`${model}, ${rot}, threshold ${threshold}`, () => {
                const opts = model === 'ona' ? { ordered: true } : { tensor: TMA_TENSOR };
                const res = ena.pria(rows, { ...BASE, threshold, ...opts, ...rotations[rot] });
                expect(res.removed).toEqual(removed);
                expect(res.variance).toBeCloseTo(variance, 9);
            });
        }
    }
});
