/**
 * Infinite windows, time-based windows, flexible horizons and custom
 * rotations match the R reference (rENA 0.4.3, tma 0.3.5, rENA.api).
 *
 * Fixture test/fixtures/windows-horizons-rotation-rs.json is generated in R
 * from inst/extdata/rs.data.csv, with units c("UserName","Condition"),
 * conversations c("Condition","GroupName","ActivityNumber") and the six RS
 * codes:
 *   inf / w4   ena.accumulate.data(..., window.size.back = Inf / 4)
 *   rot        src <- ena.make.set(<w4>, dimensions = 6)
 *              tgt <- ena.make.set(<window 2>, dimensions = 6, rotation.set = src$rotation)
 *              → src rotation/nodes/center, tgt points and tgt$model$variance
 *   tma_*      the tma branch of rENA.api's ena.generate: tma:::contexts()
 *              with hoo_rules + split_rules, tma::context_tensor(mode_column =
 *              "GameHalf", default_window = 4) with the "Second" window set
 *              to 2, then tma::accumulate(binary = TRUE)
 *     tma_fixed  rule  Condition/GroupName/ActivityNumber %in% UNIT$...,
 *                split on the conversation columns
 *     tma_flex   rules GameHalf %in% 'First'  & GroupName %in% UNIT$GroupName,
 *                      GameHalf %in% 'Second' & GroupName %in% UNIT$GroupName
 *                                             & ActivityNumber %in% UNIT$ActivityNumber,
 *                split on c("GroupName","ActivityNumber")
 *     tma_time   tma_fixed's contexts, time_column = parse_date_vector(Timestamp),
 *                windows mins_to_seconds(3), "Second" mins_to_seconds(10)
 *   times      parse_date_vector(Timestamp) for a sample of rows
 */
import fs   from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import loadENA from '../src/index.js';
import {
    parseTimes, parseTimeValue, secondsPerTimeUnit, buildHorizonContexts, resolveTensorData,
    defaultTensor,
} from '../src/tensor.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const EXTDATA   = path.resolve(__dirname, '../../inst/extdata');
const FIXTURE   = JSON.parse(fs.readFileSync(
    path.join(__dirname, 'fixtures/windows-horizons-rotation-rs.json'), 'utf8'));

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
const BASE  = {
    codes:         CODES,
    units:         ['UserName', 'Condition'],
    conversations: ['Condition', 'GroupName', 'ActivityNumber'],
};

// tma::context_tensor(mode_column = col): one mode axis over the column's
// sorted levels, weight 1, `window` everywhere except `overrides`.
function modeTensor(rows, col, window, overrides = {}) {
    const levels = {};
    [...new Set(rows.map(r => r[col]))].sort().forEach((v, i) => { levels[v] = i; });
    const n    = Object.keys(levels).length;
    const data = new Float64Array(n * 2);
    for (let c = 0; c < n; c++) { data[c] = 1; data[n + c] = window; }
    for (const [v, w] of Object.entries(overrides)) data[n + levels[v]] = w;
    return { dims: [n, 2], dimsSender: [], dimsReceiver: [], dimsMode: [0],
             factors: [col], factorLevels: { [col]: levels }, data };
}

// Max |wasm - R| over every unit's connection counts, matched by unit label.
function maxCountDiff(acc, ref) {
    const idx = new Map(acc.unitLabels.map((l, i) => [l.split('__').join('::'), i]));
    expect(acc.nUnits).toBe(ref.units.length);
    let max = 0;
    ref.units.forEach((u, r) => {
        const w = idx.get(u);
        expect(w).toBeDefined();
        for (let c = 0; c < acc.nConnections; c++) {
            max = Math.max(max, Math.abs(acc.connectionCounts[w * acc.nConnections + c] - ref.counts[r][c]));
        }
    });
    return max;
}

let ena, rows;
beforeAll(async () => {
    ena  = await loadENA();
    rows = parseCSV(fs.readFileSync(path.join(EXTDATA, 'rs.data.csv'), 'utf8'));
});

// ── infinite window ──────────────────────────────────────────────────────────

test('window: Infinity matches rENA window.size.back = Inf', () => {
    const acc = ena.accumulate(rows, { ...BASE, window: Infinity });
    expect(maxCountDiff(acc, FIXTURE.inf)).toBe(0);
    // ...and genuinely differs from a moving window
    expect(maxCountDiff(ena.accumulate(rows, { ...BASE, window: 4 }), FIXTURE.inf)).toBeGreaterThan(0);
    expect(maxCountDiff(ena.accumulate(rows, { ...BASE, window: 4 }), FIXTURE.w4)).toBe(0);
});

test('resolveTensorData clamps infinite windows to int32 and leaves weights alone', () => {
    const data = resolveTensorData(defaultTensor(Infinity, 0.5));
    expect(data[0]).toBe(0.5);
    expect(data[1]).toBe(2147483647);
});

// ── time-based windows ───────────────────────────────────────────────────────

test('parseTimeValue / parseTimes match rENA.api parse_date', () => {
    const { value, secs } = FIXTURE.times;
    value.forEach((v, i) => expect(parseTimeValue(v)).toBe(secs[i]));
    expect(parseTimeValue('01:30')).toBe(90);                    // MM:SS
    expect(parseTimeValue('1:02:03')).toBe(3723);                // HH:MM:SS
    expect(parseTimeValue('2025-01-23 12:37:13')).toBe(Date.UTC(2025, 0, 23, 12, 37, 13) / 1000);
    expect(parseTimeValue('23/01/2025')).toBe(Date.UTC(2025, 0, 23) / 1000);   // d/m/Y
    expect(parseTimeValue('01/02/2025')).toBe(Date.UTC(2025, 1, 1) / 1000);    // d/m/Y wins
    expect(Number.isNaN(parseTimeValue('next tuesday'))).toBe(true);

    // numeric columns are used as-is (including 0); an end column that is
    // numeric is a duration added to the start
    const r = [{ t: '0', d: '5' }, { t: '10', d: '2' }];
    expect(Array.from(parseTimes(r, 't'))).toEqual([0, 10]);
    expect(Array.from(parseTimes(r, 't', 'd'))).toEqual([5, 12]);
    expect(() => parseTimes([{ t: 'soon' }], 't')).toThrow(/time column 't'/);
});

test('secondsPerTimeUnit', () => {
    expect(secondsPerTimeUnit('lines')).toBeNull();
    expect(secondsPerTimeUnit("'mins'")).toBe(60);
    expect(secondsPerTimeUnit('hour')).toBe(3600);
    expect(secondsPerTimeUnit('weeks')).toBe(604800);
    expect(() => secondsPerTimeUnit('fortnights')).toThrow();
});

test('timesCol + timeUnit match tma::accumulate with a time column', () => {
    const tensor = { ...modeTensor(rows, 'GameHalf', 3, { Second: 10 }),
                     timesCol: 'Timestamp', timeUnit: 'mins' };
    expect(maxCountDiff(ena.accumulate(rows, { ...BASE, tensor }), FIXTURE.tma_time)).toBe(0);
    // the same windows read as lines give a different model
    const lines = modeTensor(rows, 'GameHalf', 3, { Second: 10 });
    expect(maxCountDiff(ena.accumulate(rows, { ...BASE, tensor: lines }), FIXTURE.tma_time)).toBeGreaterThan(0);
});

// ── horizons ─────────────────────────────────────────────────────────────────

const FLEX = { by: 'GameHalf', rules: { First: ['GroupName'], Second: ['GroupName', 'ActivityNumber'] } };

test('fixed-horizon TMA (conversation contexts) matches tma::accumulate', () => {
    const tensor = modeTensor(rows, 'GameHalf', 4, { Second: 2 });
    expect(maxCountDiff(ena.accumulate(rows, { ...BASE, tensor }), FIXTURE.tma_fixed)).toBe(0);
});

test('flexible horizons match tma contexts split on the horizon columns', () => {
    const tensor = modeTensor(rows, 'GameHalf', 4, { Second: 2 });
    const acc = ena.accumulate(rows, { ...BASE, conversations: ['GameHalf'], tensor, horizons: FLEX });
    expect(maxCountDiff(acc, FIXTURE.tma_flex)).toBe(0);
    // NOT the same as windowing within the discriminator's values
    const byDiscriminator = ena.accumulate(rows, { ...BASE, conversations: ['GameHalf'], tensor });
    expect(maxCountDiff(byDiscriminator, FIXTURE.tma_flex)).toBeGreaterThan(0);
});

test('buildHorizonContexts: rows outside every rule are in no context', () => {
    const r = [
        { m: 'a', g: '1', u: 'x' }, { m: 'a', g: '1', u: 'y' },
        { m: 'b', g: '1', u: 'y' }, { m: 'a', g: '2', u: 'y' },
    ];
    const unitOf = Int32Array.from([0, 1, 1, 1]);
    const ctx = buildHorizonContexts(r, unitOf, 2, { by: 'm', rules: { a: ['g'] } });
    expect(ctx[0]).toEqual([[0, 1]]);          // x: only group 1
    expect(ctx[1]).toEqual([[0, 1], [3]]);     // y: groups 1 and 2, never the 'b' row
    expect(() => buildHorizonContexts(r, unitOf, 2, { by: 'm', rules: { a: [] } })).toThrow(/no columns/);
});

// ── custom rotation ──────────────────────────────────────────────────────────

test('rotationSet projects into another set, as ena.make.set(rotation.set =)', () => {
    const R = FIXTURE.rot;
    const rotationSet = { rotationMatrix: R.src_rotation, nodes: R.src_nodes,
                          centerVec: R.src_center, codes: CODES };
    const fit = ena.fit(rows, { ...BASE, window: 2, dims: 6, rotationSet });
    const idx = new Map(fit.model.unitLabels.map((l, i) => [l.split('__').join('::'), i]));
    let maxPt = 0;
    R.tgt_units.forEach((u, r) => {
        for (let d = 0; d < 6; d++) {
            maxPt = Math.max(maxPt, Math.abs(fit.points[idx.get(u) * fit.dims + d] - R.tgt_points[r][d]));
        }
    });
    expect(maxPt).toBeLessThan(1e-12);
    // nodes are the rotation set's
    for (let c = 0; c < CODES.length; c++)
        for (let d = 0; d < 6; d++) expect(fit.rotation.nodes[c * fit.dims + d]).toBe(R.src_nodes[c][d]);
    expect(fit.model.centroids.length).toBe(fit.nUnits * fit.dims);

    // a model whose codes are in a different order projects identically
    const order = [3, 0, 5, 1, 4, 2];
    const fit2 = ena.fit(rows, { ...BASE, codes: order.map(i => CODES[i]), window: 2, dims: 6, rotationSet });
    for (let i = 0; i < fit.points.length; i++) expect(fit2.points[i]).toBeCloseTo(fit.points[i], 12);
});

test('rotationSet variance is the share of total variance, as R reports it', () => {
    // R stores the full rotation; the webtool keeps only the first 6 columns.
    // Either way the percentages must be R's (diag(var(points)) / total).
    const R = FIXTURE.rot;
    for (const cols of [R.src_rotation[0].length, 6]) {
        const rotationSet = { rotationMatrix: R.src_rotation.map(r => r.slice(0, cols)),
                              nodes: R.src_nodes.map(r => r.slice(0, cols)),
                              centerVec: R.src_center, codes: CODES };
        const fit = ena.fit(rows, { ...BASE, window: 2, dims: 15, rotationSet });
        expect(fit.dims).toBe(cols);
        for (let d = 0; d < Math.min(cols, 6); d++) {
            expect(fit.model.variance[d]).toBeCloseTo(R.tgt_variance[d], 12);
        }
    }
});

test('rotationSet built from other codes is rejected', () => {
    const R = FIXTURE.rot;
    expect(() => ena.fit(rows, { ...BASE, codes: CODES.slice(0, 5), window: 2, rotationSet: {
        rotationMatrix: R.src_rotation, nodes: R.src_nodes, centerVec: R.src_center, codes: CODES,
    } })).toThrow(/connections/);
});
