/**
 * Plain moving-window models run through the tensor path (defaultTensor).
 *
 * fit() / accumulate() no longer have a separate stanza-window accumulator:
 * a plain window is expressed as defaultTensor(window) so the per-line
 * finalisation (fold / binarize / weight) lives in one place. These tests pin
 * that the tensor path reproduces the former stanza-window results exactly.
 *
 * The reference below is the former windowed path, kept verbatim in spirit:
 * libqe's accumulate_stanza per conversation (binarized in the kernel when
 * binary), the weight transform applied to each row, then rows summed by unit.
 * Before the switch, plain-vs-tensor full models agreed across 48 combinations
 * (windows × weight models × svd/means/gmr) to ≤ 3e-12 on every output.
 *
 * R anchor: the tiny example matches rENA's legacy ena.accumulate.data()
 * (weight.by = "binary" / "product" / sqrt / log1p, window.size.back = 3).
 */
import fs   from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import loadENA from '../src/index.js';
import { parseData } from '../src/data.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const EXTDATA   = path.resolve(__dirname, '../../inst/extdata');

// ── minimal RFC-4180 CSV parser (same as parity.test.js) ─────────────────────

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

// ── reference: the former stanza-window accumulation ─────────────────────────

const WEIGHTS = {
    binary:  null,
    product: x => x,
    sqrt:    Math.sqrt,
    log:     Math.log1p,
};

function stanzaReference(qe, rows, { codes, units, conversations, window, weightModel }) {
    const weightFn = WEIGHTS[weightModel ?? 'binary'];
    const binary   = !weightFn;
    const { codeMatrix, nRows, nCodes, nUnits, unitOf, convoGroups } =
        parseData(rows, codes, units, conversations);
    const nConn    = qe.choose_two(nCodes);
    const networks = new Float64Array(nUnits * nConn);
    const rowCC    = new Float64Array(nRows * nConn);

    for (const [, rowIndices] of convoGroups) {
        const n = rowIndices.length;
        const convoCodes = new Float64Array(n * nCodes);
        rowIndices.forEach((src, r) =>
            convoCodes.set(codeMatrix.subarray(src * nCodes, (src + 1) * nCodes), r * nCodes));
        const stanza = qe.accumulate_stanza(convoCodes, n, nCodes, window, 0, binary);
        rowIndices.forEach((src, r) => {
            for (let c = 0; c < nConn; c++) {
                let v = stanza.data[r * nConn + c];
                if (weightFn) v = weightFn(v);
                rowCC[src * nConn + c] = v;
                networks[unitOf[src] * nConn + c] += v;
            }
        });
    }
    return { networks, rowCC };
}

const maxAbsDiff = (a, b) => {
    let m = 0;
    for (let i = 0; i < a.length; i++) m = Math.max(m, Math.abs(a[i] - b[i]));
    return m;
};

// ── fixtures ─────────────────────────────────────────────────────────────────

const RS_CODES = ['Data', 'Technical Constraints', 'Performance Parameters',
                  'Client and Consultant Requests', 'Design Reasoning', 'Collaboration'];
const RS_BASE  = { codes: RS_CODES, units: ['Condition', 'UserName'],
                   conversations: ['Condition', 'GroupName'], dims: 2 };

let ena;
let rsRows;

beforeAll(async () => {
    ena    = await loadENA();
    rsRows = parseCSV(fs.readFileSync(path.join(EXTDATA, 'rs.data.csv'), 'utf8'));
});

// ── tensor path == former stanza-window path, on RS.data ─────────────────────

describe('plain window via defaultTensor matches stanza-window accumulation (RS.data)', () => {
    // 1e9 stands in for an infinite (whole-conversation) window.
    for (const window of [2, 4, 7, 1e9]) {
        for (const weightModel of Object.keys(WEIGHTS)) {
            test(`window=${window === 1e9 ? 'whole conversation' : window}, weight=${weightModel}`, () => {
                const opts = { ...RS_BASE, window,
                               ...(weightModel === 'binary' ? {} : { weightModel }) };
                const ref  = stanzaReference(ena.qe, rsRows, opts);
                const m    = ena.fit(rsRows, opts);

                expect(m.nConnections).toBe(15);
                expect(maxAbsDiff(m.connectionCounts, ref.networks)).toBeLessThan(1e-10);
                expect(maxAbsDiff(m.rowConnectionCounts, ref.rowCC)).toBeLessThan(1e-10);
                expect(Array.from(m.model.rowConnectionCounts)).toEqual(Array.from(m.rowConnectionCounts));
            });
        }
    }

    test('accumulate() matches the reference too (binary, window 4)', () => {
        const opts = { ...RS_BASE, window: 4 };
        const ref  = stanzaReference(ena.qe, rsRows, opts);
        const acc  = ena.accumulate(rsRows, opts);
        expect(maxAbsDiff(acc.connectionCounts, ref.networks)).toBe(0);
        expect(maxAbsDiff(acc.rowConnectionCounts, ref.rowCC)).toBe(0);
    });
});

// ── R anchor: legacy ena.accumulate.data() on a tiny non-binary example ──────

describe('weight models match R ena.accumulate.data (window.size.back = 3)', () => {
    // One unit, one conversation; counts > 1 so product / sqrt / log differ.
    const ROWS = [
        { u: 'x', c: '1', A: 2, B: 0, C: 1 },
        { u: 'x', c: '1', A: 1, B: 3, C: 0 },
        { u: 'x', c: '1', A: 0, B: 1, C: 2 },
    ];
    const BASE = { codes: ['A', 'B', 'C'], units: ['u'], conversations: ['c'], window: 3, dims: 2 };
    // Connection order: A & B, A & C, B & C
    const R = {
        binary:  [2, 3, 2],
        product: [12, 9, 12],
        sqrt:    [4.73205080756888, 4.86370330515627, 4.73205080756888],
        log:     [3.68887945411394, 3.73766961828337, 3.68887945411394],
    };

    for (const [weightModel, expected] of Object.entries(R)) {
        test(`weight=${weightModel}`, () => {
            const m = ena.fit(ROWS, { ...BASE,
                                      ...(weightModel === 'binary' ? {} : { weightModel }) });
            expected.forEach((v, i) => expect(m.connectionCounts[i]).toBeCloseTo(v, 12));
        });
    }
});

// ── ordered without an explicit tensor is now directed ───────────────────────

test('ordered: true without a tensor builds directed (n²) networks', () => {
    const opts = { ...RS_BASE, window: 4, ordered: true };
    const m    = ena.fit(rsRows, opts);
    const t    = ena.fit(rsRows, { ...opts, tensor: ena.defaultTensor(4) });
    expect(m.nConnections).toBe(RS_CODES.length ** 2);
    expect(maxAbsDiff(m.connectionCounts, t.connectionCounts)).toBe(0);
});
