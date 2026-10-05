/**
 * model.variance is each dimension's share of the TOTAL variance, matching R's
 * set$model$variance, whatever number of dimensions is kept.
 *
 * rena-wasm used to divide by the variance of only the returned dims, so a
 * default 2-dim fit always reported shares summing to 1 (58%/42% instead of
 * R's 32%/23% on RS.data). The other parity tests request every dimension, so
 * they could not see it.
 *
 * R reference (rENA 0.4.11, libqe 0.1.6) from inst/extdata/rs.data.csv:
 *   acc <- ena.accumulate.data(units = x[, c("Condition","UserName")],
 *            conversation = x[, c("Condition","GroupName")], codes = x[, codes],
 *            window.size.back = 4)
 *   ena.make.set(acc)                                          # SVD
 *   ena.make.set(acc, rotation.by = ena.rotate.by.mean,
 *                rotation.params = list(FirstGame = fg, SecondGame = !fg))
 *   ena.make.set(acc, rotation.by = ena.rotate.by.generalized,
 *                rotation.params = list(x_var = "Condition",
 *                                       select_2_groups = c("FirstGame","SecondGame")))
 *   → model$variance[1:4]  (identical for dimensions = 2)
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
                conversations: ['Condition', 'GroupName'], window: 4 };

const R_VARIANCE = {
    svd:  [0.318838644779, 0.230090104332, 0.165653308295, 0.097598793289],
    mean: [0.301559417113, 0.232161284890, 0.170686333275, 0.098205831448],
    gmr:  [0.301559417113, 0.232161284890, 0.170686333275, 0.098205831448],
};

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

describe('model.variance matches R set$model$variance on RS.data', () => {
    for (const rot of Object.keys(R_VARIANCE)) {
        for (const dims of [2, 4, 15]) {
            test(`${rot}, dims = ${dims}`, () => {
                const fit = ena.fit(rows, { ...BASE, dims, ...rotations[rot] });
                expect(fit.dims).toBe(dims);
                for (let d = 0; d < Math.min(dims, 4); d++)
                    expect(fit.model.variance[d]).toBeCloseTo(R_VARIANCE[rot][d], 9);
            });
        }
    }
});
