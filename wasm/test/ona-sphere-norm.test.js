/**
 * Ordered (ONA) models with sphereNorm on and off match
 * ona::model(normalize = sphere_norm / skip_sphere_norm).
 *
 * Fixture test/fixtures/ona-sphere-norm-rs.json is generated in R (ona 0.1.2,
 * rENA source with skip_sphere_norm()) from inst/extdata/rs.data.csv:
 *   acc <- rENA::accumulate(x, c("Condition","UserName"), codes,
 *                           c("Condition","GroupName"), default_window = 4,
 *                           ordered = TRUE)
 *   for normalize in rENA::sphere_norm / rENA::skip_sphere_norm:
 *     ona::model(acc, normalize =)                             # svd
 *     ona::model(acc, normalize =, rotate.using = "mean",
 *                rotation.params = list(FirstGame, SecondGame)) # mean
 *   → points, nodes and centroids on dims 1:2
 * The sphere_norm case reproduces ona-model-rs.json to 5e-16.
 */
import fs   from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import loadENA from '../src/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const EXTDATA   = path.resolve(__dirname, '../../inst/extdata');
const FIXTURE   = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/ona-sphere-norm-rs.json'), 'utf8'));

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

let ena, rows;
beforeAll(async () => {
    ena  = await loadENA();
    rows = parseCSV(fs.readFileSync(path.join(EXTDATA, 'rs.data.csv'), 'utf8'));
});

function rotationOpts(rot) {
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

describe.each([[true], [false]])('ordered fit(sphereNorm: %s) matches ona::model()', (sphereNorm) => {
    test.each([['svd'], ['mean']])('%s rotation', (rot) => {
        const R   = FIXTURE[`sphere_${String(sphereNorm).toUpperCase()}`][rot];
        const m   = ena.fit(rows, { ...BASE, dims: CODES.length ** 2, sphereNorm, ...rotationOpts(rot) });
        const idx = FIXTURE.units.map(u => m.model.unitLabels.indexOf(u.replace('::', '__')));
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
        }
    });
});

test('sphereNorm: false changes ordered models', () => {
    const on  = ena.fit(rows, { ...BASE, dims: 2 });
    const off = ena.fit(rows, { ...BASE, dims: 2, sphereNorm: false });
    const diff = Math.max(...Array.from(on.points, (v, i) => Math.abs(Math.abs(v) - Math.abs(off.points[i]))));
    expect(diff).toBeGreaterThan(0.1);
});
