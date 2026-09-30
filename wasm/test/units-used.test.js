/**
 * unitsUsed (= R's `units.used`): excluded units' rows stay in the data as
 * context for the included units' windows, but the excluded units are not
 * modeled, so they never reach sphere norm / centering / rotation.
 *
 * Fixture test/fixtures/units-used-rs.json is generated in R (rENA 0.4.3) from
 * inst/extdata/rs.data.csv, keeping every other unit:
 *   acc <- ena.accumulate.data(units = x[, c("Condition","UserName")],
 *            conversation = x[, c("Condition","GroupName")], codes = x[, codes],
 *            window.size.back = 4, units.used = used)
 *   set <- ena.make.set(acc)
 */
import fs   from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import loadENA from '../src/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const EXTDATA   = path.resolve(__dirname, '../../inst/extdata');
const FIXTURE   = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/units-used-rs.json'), 'utf8'));

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
const OPTS  = { codes: CODES, units: ['Condition', 'UserName'],
                conversations: ['Condition', 'GroupName'], window: 4, dims: 2 };
// R unit names join with '::'; rena-wasm unit keys join with '__'.
const toKey = (name) => name.split('::').join('__');

let ena, rows;
beforeAll(async () => {
    ena  = await loadENA();
    rows = parseCSV(fs.readFileSync(path.join(EXTDATA, 'rs.data.csv'), 'utf8'));
});

const row = (flat, i, n) => Array.from(flat.slice(i * n, (i + 1) * n));

describe('unitsUsed', () => {
    test('models only the used units, in R order', () => {
        const m = ena.fit(rows, { ...OPTS, unitsUsed: FIXTURE.used.map(toKey) });
        expect(m.nUnits).toBe(FIXTURE.unitNames.length);
        expect(m.model.unitLabels).toEqual(FIXTURE.unitNames.map(toKey));
        expect(m.metaData).toHaveLength(FIXTURE.unitNames.length);
    });

    test('connection counts match R units.used (excluded rows kept as context)', () => {
        const m = ena.fit(rows, { ...OPTS, unitsUsed: FIXTURE.used.map(toKey) });
        FIXTURE.connectionCounts.forEach((expected, u) => {
            expect(row(m.connectionCounts, u, m.nConnections)).toEqual(expected);
        });
    });

    test('line weights and points match R', () => {
        const m = ena.fit(rows, { ...OPTS, unitsUsed: FIXTURE.used.map(toKey) });
        FIXTURE.lineWeights.forEach((expected, u) => {
            row(m.lineWeights, u, m.nConnections).forEach((v, c) => expect(v).toBeCloseTo(expected[c], 9));
        });
        // SVD axes are sign-indeterminate: align each dimension's sign to R.
        for (let d = 0; d < 2; d++) {
            const sign = Math.sign(m.points[d]) === Math.sign(FIXTURE.points12[0][d]) ? 1 : -1;
            FIXTURE.points12.forEach((expected, u) => {
                expect(sign * m.points[u * m.dims + d]).toBeCloseTo(expected[d], 6);
            });
        }
    });

    test('differs from dropping the excluded units\' rows', () => {
        const used = new Set(FIXTURE.used.map(toKey));
        const dropped = rows.filter(r => used.has(`${r.Condition}__${r.UserName}`));
        const kept = ena.fit(rows, { ...OPTS, unitsUsed: [...used] });
        const drop = ena.fit(dropped, OPTS);
        expect(drop.model.unitLabels).toEqual(kept.model.unitLabels);
        const diff = Array.from(kept.connectionCounts).some((v, i) => v !== drop.connectionCounts[i]);
        expect(diff).toBe(true);
    });

    test('no unitsUsed models every unit', () => {
        const all = ena.fit(rows, OPTS);
        const every = ena.fit(rows, { ...OPTS, unitsUsed: all.model.unitLabels });
        expect(Array.from(every.connectionCounts)).toEqual(Array.from(all.connectionCounts));
    });

    test('accumulate() and pria() honour unitsUsed', () => {
        const unitsUsed = FIXTURE.used.map(toKey);
        const acc = ena.accumulate(rows, { ...OPTS, unitsUsed });
        expect(acc.nUnits).toBe(FIXTURE.unitNames.length);
        expect(acc._call.unitsUsed).toEqual(unitsUsed);
        FIXTURE.connectionCounts.forEach((expected, u) => {
            expect(row(acc.connectionCounts, u, acc.nConnections)).toEqual(expected);
        });
        expect(() => ena.pria(rows, { ...OPTS, unitsUsed })).not.toThrow();
    });

    test('unitsUsed matching no units throws', () => {
        expect(() => ena.fit(rows, { ...OPTS, unitsUsed: ['nobody__here'] }))
            .toThrow(/matched no units/);
    });
});
