/**
 * sphereNorm and centerAlignToOrigin match rENA's ena.make.set(norm.by =,
 * center.align.to.origin =) (rENA 0.4.3).
 *
 * Fixture test/fixtures/norm-center-rs.json is generated in R from
 * inst/extdata/rs.data.csv plus a zero-network unit ("zero user", the first
 * three rows with every code 0, in its own GroupName "ZeroGroup"):
 *   acc <- ena.accumulate.data(units = c("UserName","Condition"),
 *            conversation = c("Condition","GroupName"), codes, window.size.back = 4)
 *   for norm.by in fun_sphere_norm / fun_skip_sphere_norm,
 *       center.align.to.origin in TRUE / FALSE:
 *     ena.make.set(acc, dimensions = 6, norm.by =, center.align.to.origin =)
 *       → rotation$center.vec, points[, 1:6]
 *   rot: src <- ena.make.set(acc, dimensions = 6, center.align.to.origin = FALSE)
 *        ena.make.set(<window 2>, dimensions = 6, rotation.set = src$rotation,
 *                     center.align.to.origin = FALSE)
 *
 * SVD axes are compared up to each dimension's sign.
 */
import fs   from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import loadENA from '../src/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const EXTDATA   = path.resolve(__dirname, '../../inst/extdata');
const FIXTURE   = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/norm-center-rs.json'), 'utf8'));

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
const BASE  = { codes: CODES, units: ['UserName', 'Condition'], conversations: ['Condition', 'GroupName'] };
const DIMS  = 6;

let ena, rows;
beforeAll(async () => {
    ena  = await loadENA();
    rows = parseCSV(fs.readFileSync(path.join(EXTDATA, 'rs.data.csv'), 'utf8'));
    const zero = rows.slice(0, 3).map(r => ({ ...r, UserName: 'zero user', GroupName: 'ZeroGroup',
                                               ...Object.fromEntries(CODES.map(c => [c, '0'])) }));
    rows = rows.concat(zero);
});

// Max |wasm - R| over the first DIMS dims of every unit's point, each
// dimension's sign aligned to R's.
function maxPointDiff(fit, refPoints) {
    const idx = new Map(fit.model.unitLabels.map((l, i) => [l.split('__').join('::'), i]));
    let max = 0;
    for (let d = 0; d < DIMS; d++) {
        const diff = (sign) => FIXTURE.units.reduce((m, u, r) =>
            Math.max(m, Math.abs(sign * fit.points[idx.get(u) * fit.dims + d] - refPoints[r][d])), 0);
        max = Math.max(max, Math.min(diff(1), diff(-1)));
    }
    return max;
}

const pointOf = (fit, label) => {
    const u = fit.model.unitLabels.indexOf(label);
    return Array.from(fit.points.subarray(u * fit.dims, u * fit.dims + DIMS));
};

describe.each([
    [true,  true],
    [true,  false],
    [false, true],
    [false, false],
])('sphereNorm=%s, centerAlignToOrigin=%s', (sphereNorm, centerAlignToOrigin) => {
    const ref = () => FIXTURE[`sphere_${String(sphereNorm).toUpperCase()}__align_${String(centerAlignToOrigin).toUpperCase()}`];

    test('center vector and points match ena.make.set', () => {
        const fit = ena.fit(rows, { ...BASE, window: 4, dims: DIMS, sphereNorm, centerAlignToOrigin });
        const r = ref();
        r.center.forEach((v, c) => expect(Math.abs(fit.rotation.centerVec[c] - v)).toBeLessThan(1e-12));
        expect(maxPointDiff(fit, r.points)).toBeLessThan(1e-9);

        // the zero-network unit stays at the origin only when aligned to it
        const zero = pointOf(fit, 'zero user__FirstGame');
        const atOrigin = zero.every(v => Math.abs(v) < 1e-12);
        expect(atOrigin).toBe(centerAlignToOrigin);
    });
});

test('rotationSet with centerAlignToOrigin=false shifts zero networks by the set\'s center', () => {
    const R = FIXTURE.rot;
    const fit = ena.fit(rows, { ...BASE, window: 2, dims: DIMS, centerAlignToOrigin: false,
        rotationSet: { rotationMatrix: R.src_rotation, nodes: R.src_nodes, centerVec: R.src_center, codes: CODES } });
    const idx = new Map(fit.model.unitLabels.map((l, i) => [l.split('__').join('::'), i]));
    let max = 0;
    FIXTURE.units.forEach((u, r) => {
        for (let d = 0; d < DIMS; d++) max = Math.max(max, Math.abs(fit.points[idx.get(u) * fit.dims + d] - R.tgt_points[r][d]));
    });
    expect(max).toBeLessThan(1e-12);
});

test('ordered models ignore centerAlignToOrigin (ona::model centring)', () => {
    const a = ena.fit(rows, { ...BASE, window: 4, ordered: true });
    const b = ena.fit(rows, { ...BASE, window: 4, ordered: true, centerAlignToOrigin: false });
    expect(Array.from(b.points)).toEqual(Array.from(a.points));
});
