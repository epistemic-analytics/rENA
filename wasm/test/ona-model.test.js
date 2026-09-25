/**
 * Ordered (ONA) models match ona::model() — the ONA standard.
 *
 * Fixture test/fixtures/ona-model-rs.json is generated in R (ona 0.1.2,
 * rENA 0.4.8, PRIA 0.1.3) from inst/extdata/rs.data.csv:
 *   acc <- rENA::accumulate(x, c("Condition","UserName"), codes,
 *                           c("Condition","GroupName"), default_window = 4,
 *                           ordered = TRUE)
 *   ona::model(acc)                                   # SVD
 *   ona::model(acc, rotate.using = "mean",
 *              rotation.params = list(FirstGame, SecondGame))
 *   PRIA::pria(set, remove.num = 3, threshold = 0.95, rebuild = <same model>)
 * for RS.data and for RS.data plus one zero-network unit ("zero user": the
 * first three FirstGame / GroupName 2 rows, all codes 0).
 *
 * ona::model centres with zero networks left out of the mean but shifted by
 * it, places nodes with directed_node_positions, and translates points and
 * nodes so the points' mean is at the origin.
 */
import fs   from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import loadENA from '../src/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const EXTDATA   = path.resolve(__dirname, '../../inst/extdata');
const FIXTURE   = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/ona-model-rs.json'), 'utf8'));

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
                conversations: ['Condition', 'GroupName'], window: 4, ordered: true };
const dotted = (c) => c.replace(/ /g, '.');

let ena;
const datasets = {};

beforeAll(async () => {
    ena = await loadENA();
    const rows = parseCSV(fs.readFileSync(path.join(EXTDATA, 'rs.data.csv'), 'utf8'));
    const zero = rows.filter(r => r.Condition === 'FirstGame' && r.GroupName === '2').slice(0, 3)
        .map(r => ({ ...r, UserName: 'zero user',
                     ...Object.fromEntries(CODES.map(c => [c, '0'])) }));
    datasets.rs      = rows;
    datasets.rs_zero = rows.concat(zero);
});

function rotationOpts(rows, rot) {
    if (rot !== 'mean') return {};
    const seen = new Map();
    for (const r of rows) {
        const key = BASE.units.map(c => String(r[c])).join('__');
        if (!seen.has(key)) seen.set(key, r);
    }
    const groupA = [], groupB = [];
    [...seen.values()].forEach((r, i) => (r.Condition === 'FirstGame' ? groupA : groupB).push(i));
    return { rotation: 'mean', groupA, groupB };
}

describe('ordered fit() matches ona::model()', () => {
    for (const key of Object.keys(FIXTURE)) {
        const [dn, rot] = [key.replace(/_(svd|mean)$/, ''), key.match(/(svd|mean)$/)[1]];
        test(key, () => {
            const R    = FIXTURE[key];
            const rows = datasets[dn];
            const m    = ena.fit(rows, { ...BASE, dims: CODES.length ** 2, ...rotationOpts(rows, rot) });
            const idx  = R.units.map(u => m.model.unitLabels.indexOf(u.replace('::', '__')));
            expect(idx.every(i => i >= 0)).toBe(true);

            for (let d = 0; d < 2; d++) {
                const pts = idx.map(i => m.points[i * m.dims + d]);
                // SVD axes have arbitrary sign: align on the points, then apply
                // the same sign to nodes and centroids.
                const dot  = pts.reduce((t, v, i) => t + v * R.points[i][d], 0);
                const sign = dot >= 0 ? 1 : -1;
                pts.forEach((v, i) => expect(sign * v).toBeCloseTo(R.points[i][d], 9));
                CODES.forEach((_, c) =>
                    expect(sign * m.rotation.nodes[c * m.dims + d]).toBeCloseTo(R.nodes[c][d], 9));
                idx.forEach((i, t) =>
                    expect(sign * m.model.centroids[i * m.dims + d]).toBeCloseTo(R.centroids[t][d], 9));
                expect(m.model.variance[d]).toBeCloseTo(R.variance[d], 9);
            }
        });
    }
});

describe('ordered pria() matches PRIA::pria on ona::model()', () => {
    for (const key of Object.keys(FIXTURE)) {
        const [dn, rot] = [key.replace(/_(svd|mean)$/, ''), key.match(/(svd|mean)$/)[1]];
        test(key, () => {
            const R    = FIXTURE[key];
            const rows = datasets[dn];
            const res  = ena.pria(rows, { ...BASE, removeNum: 3, threshold: 0.95, ...rotationOpts(rows, rot) });
            expect(res.removed.map(dotted)).toEqual(R.pria_removed);
            expect(res.variance).toBeCloseTo(R.pria_variance, 9);
        });
    }
});
