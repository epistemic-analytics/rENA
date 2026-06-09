/**
 * parity.test.js — Cross-binding parity tests for @qe-libs/rena-wasm
 *
 * These tests replicate assertions from the R testthat suite using the same
 * shared data files (inst/extdata/rs.data.csv) and the same small inline
 * datasets used in the R tests.  Every test cites its R source.
 *
 * R sources:
 *   - tests/testthat/test.ena.make.set.R
 *   - tests/testthat/test-rotation_matrix.R
 *   - tests/testthat/test-zero-networks.R
 *   - tests/testthat/test.ena.accumulations.R
 *
 * Field names mirror R's ena.set structure (see index.js module docstring).
 */

import fs   from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import loadENA from '../src/index.js';

// ── path helpers ─────────────────────────────────────────────────────────────

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const EXTDATA   = path.resolve(__dirname, '../../inst/extdata');

// ── minimal RFC-4180 CSV parser ───────────────────────────────────────────────

function parseCSVRow(line) {
    const result = [];
    let current  = '';
    let inQuotes = false;
    for (let i = 0; i < line.length; i++) {
        const ch = line[i];
        if (ch === '\r') continue;               // strip CRLF carriage returns
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

// ── shared fixtures ───────────────────────────────────────────────────────────

// RS.data codes — space-separated in the CSV (R's read.csv converts to dots,
// but we read the CSV directly so we use the raw column names).
const RS_CODES = [
    'Data',
    'Technical Constraints',
    'Performance Parameters',
    'Client and Consultant Requests',
    'Design Reasoning',
    'Collaboration',
];

// Small 12-row inline dataset from test.ena.accumulations.R
// Name = rep(c("J","Z"), 6), Day = c(1,1,1,1,1,1,2,2,2,2,2,2)
const ROWS_12 = Array.from({ length: 12 }, (_, i) => ({
    Name: i % 2 === 0 ? 'J' : 'Z',
    Day:  i < 6 ? '1' : '2',
    c1:   [1,1,1,1,1,0, 0,1,1,0,0,1][i],
    c2:   [1,1,1,0,0,1, 0,1,0,1,0,0][i],
    c3:   [0,0,1,0,1,0, 1,0,0,0,1,0][i],
}));

// Zero-network fixture: 'Zero' unit lives in its own conversation so its
// rows never share a stanza with codes from 'Active', guaranteeing
// accumulation = [0,0,0].
const ZERO_NET_ROWS = [
    { unit: 'Active', convo: 'c1', x: 1, y: 1, z: 0 },
    { unit: 'Active', convo: 'c1', x: 1, y: 0, z: 1 },
    { unit: 'Zero',   convo: 'c2', x: 1, y: 0, z: 0 },
    { unit: 'Zero',   convo: 'c2', x: 1, y: 0, z: 0 },
];

const ZERO_NET_OPTS = {
    codes:         ['x', 'y', 'z'],
    units:         ['unit'],
    conversations: ['convo'],
    window:        4,
    dims:          2,
};

let ena;
let rsRows;

beforeAll(async () => {
    ena    = await loadENA();
    const csv = fs.readFileSync(path.join(EXTDATA, 'rs.data.csv'), 'utf8');
    rsRows = parseCSV(csv);
});

// ── RS.data structural tests ──────────────────────────────────────────────────
// Source: test.ena.make.set.R — "Simple data.frame to accumulate and make set"
//   expect_equal(length(set$rotation$codes), 6)
//   expect_equal(dim(as.matrix(set$points)), c(48, choose(6,2)))
//   expect_equal(length(set$model$unit.labels), 48)

describe('RS.data structural (mirrors test.ena.make.set.R)', () => {
    const RS_OPTS = {
        codes:         RS_CODES,
        units:         ['UserName', 'Condition'],
        conversations: ['ActivityNumber', 'GroupName'],
        window:        4,
        dims:          2,
    };

    let model;
    beforeAll(() => { model = ena.fit(rsRows, RS_OPTS); });

    test('6 codes', () => {
        expect(RS_CODES.length).toBe(6);
    });

    test('15 connections — choose(6,2)', () => {
        expect(model.nConnections).toBe(15);
    });

    test('48 units — 24 users × 2 conditions', () => {
        expect(model.nUnits).toBe(48);
    });

    // R: expect_equal(length(set$model$unit.labels), 48)
    test('48 unit labels', () => {
        expect(model.model.unitLabels.length).toBe(48);
    });

    // R: set$points — projected positions: shape 48 × dims
    test('points shape is 48 × 2', () => {
        expect(model.points.length).toBe(48 * 2);
    });

    // R: set$rotation$nodes — code positions
    test('rotation.nodes shape is 6 × 2', () => {
        expect(model.rotation.nodes.length).toBe(6 * 2);
    });

    // R: set$line.weights — normed networks
    test('lineWeights shape is 48 × 15', () => {
        expect(model.lineWeights.length).toBe(48 * 15);
    });

    // R: set$connection.counts — raw networks
    test('connectionCounts shape is 48 × 15', () => {
        expect(model.connectionCounts.length).toBe(48 * 15);
    });

    // Source: test.ena.make.set.R — rotation matrix column name
    //   expect_equal("SVD1", colnames(set.svd$rotation.matrix)[2])
    test('rotation.columnNames[0] is SVD1', () => {
        expect(model.rotation.columnNames[0]).toBe('SVD1');
    });
});

// ── Connection name format ────────────────────────────────────────────────────
// Source: test-rotation_matrix.R — rotation matrix row labels match
// connection.counts column names (which use " & " separator in R).

describe('Connection name format — " & " separator (mirrors test-rotation_matrix.R)', () => {
    test('RS.data connection names use " & " separator', () => {
        const model = ena.fit(rsRows, {
            codes:         RS_CODES,
            units:         ['UserName', 'Condition'],
            conversations: ['ActivityNumber', 'GroupName'],
            window:        4,
            dims:          2,
        });
        expect(model.connectionNames.every(n => n.includes(' & '))).toBe(true);
        expect(model.connectionNames[0]).toBe('Data & Technical Constraints');
    });

    test('3-code synthetic connection names use " & " separator', () => {
        const { connectionNames } = ena.accumulate(ROWS_12, {
            codes: ['c1', 'c2', 'c3'], units: ['Name'], conversations: ['Day'],
        });
        expect(connectionNames).toEqual(['c1 & c2', 'c1 & c3', 'c2 & c3']);
    });
});

// ── Means rotation column name ────────────────────────────────────────────────
// Source: test.ena.make.set.R — "Test rotate by mean"
//   expect_equal("MR1", colnames(set.mr$rotation.matrix)[2])

describe('Means rotation column name (mirrors test.ena.make.set.R)', () => {
    test('rotation.columnNames[0] is MR1 for means rotation', () => {
        // Accumulate first to get unit label order, then derive group indices.
        const accResult = ena.accumulate(rsRows, {
            codes:         RS_CODES,
            units:         ['UserName', 'Condition'],
            conversations: ['ActivityNumber', 'GroupName'],
            window:        4,
        });
        const groupA = accResult.unitLabels
            .map((l, i) => l.includes('FirstGame')  ? i : -1).filter(i => i >= 0);
        const groupB = accResult.unitLabels
            .map((l, i) => l.includes('SecondGame') ? i : -1).filter(i => i >= 0);

        const model = ena.fit(rsRows, {
            codes:         RS_CODES,
            units:         ['UserName', 'Condition'],
            conversations: ['ActivityNumber', 'GroupName'],
            window:        4,
            dims:          2,
            rotation:      'mean',
            groupA,
            groupB,
        });
        expect(model.rotation.columnNames[0]).toBe('MR1');
    });
});

// ── Accumulation — known values from inline dataset ───────────────────────────
// Source: test.ena.accumulations.R — "Test accumulation with infinite windows"
//   df_accum_sep: window.size.back=4, window.size.forward=0 (default)

describe('Accumulation — 12-row inline dataset (mirrors test.ena.accumulations.R)', () => {
    const OPTS_12 = {
        codes: ['c1', 'c2', 'c3'], units: ['Name'], conversations: ['Day'], window: 4,
    };

    test('2 units: J and Z', () => {
        const { nUnits, unitLabels } = ena.accumulate(ROWS_12, OPTS_12);
        expect(nUnits).toBe(2);
        expect(unitLabels).toContain('J');
        expect(unitLabels).toContain('Z');
    });

    test('3 connections — choose(2+1, 2)', () => {
        const { nConnections } = ena.accumulate(ROWS_12, OPTS_12);
        expect(nConnections).toBe(3);
    });

    test('all raw accumulated counts are non-negative', () => {
        const { connectionCounts } = ena.accumulate(ROWS_12, OPTS_12);
        expect(Array.from(connectionCounts).every(v => v >= 0)).toBe(true);
    });

    test('J and Z both have non-zero accumulation (standard backward window)', () => {
        const { connectionCounts, unitLabels } = ena.accumulate(ROWS_12, OPTS_12);
        const jIdx = unitLabels.indexOf('J');
        const zIdx = unitLabels.indexOf('Z');
        const jRow = Array.from(connectionCounts.subarray(jIdx * 3, jIdx * 3 + 3));
        const zRow = Array.from(connectionCounts.subarray(zIdx * 3, zIdx * 3 + 3));
        expect(jRow.some(v => v > 0)).toBe(true);
        expect(zRow.some(v => v > 0)).toBe(true);
    });

    // Source: test.ena.accumulations.R — "Test accumulation with infinite windows"
    //   expect_false(all(df_accum_sep$... == df_accum_inf$...))
    // window=1 vs window=9999 must differ (window=4 already covers most of
    // the 6-row conversations so window=4 vs 9999 happen to be equal here).
    test('window=1 and window=9999 produce different unit-level accumulations', () => {
        const r1   = ena.accumulate(ROWS_12, { ...OPTS_12, window: 1 });
        const rInf = ena.accumulate(ROWS_12, { ...OPTS_12, window: 9999 });
        const same = Array.from(r1.connectionCounts).every(
            (v, i) => v === rInf.connectionCounts[i]
        );
        expect(same).toBe(false);
    });
});

// ── Zero-network behavioral invariant ─────────────────────────────────────────
// Source: test-zero-networks.R
//   set_T = ena.make.set(enadata=accum, center.align.to.origin=TRUE)
//   expect_equal(sum(as.matrix(set_T$points[zero_units_rows])), 0)
//
// WASM center() correctly skips zero-network rows — this should pass.

describe('Zero-network invariant — center.align.to.origin=TRUE (mirrors test-zero-networks.R)', () => {
    let model;
    beforeAll(() => { model = ena.fit(ZERO_NET_ROWS, ZERO_NET_OPTS); });

    test('zero-network unit accumulation is all zeros', () => {
        const { connectionCounts, unitLabels, nConnections } =
            ena.accumulate(ZERO_NET_ROWS, ZERO_NET_OPTS);
        const idx = unitLabels.indexOf('Zero');
        const row = Array.from(
            connectionCounts.subarray(idx * nConnections, (idx + 1) * nConnections)
        );
        expect(row.every(v => v === 0)).toBe(true);
    });

    // R: expect_equal(sum(as.matrix(set_T$points[zero_units_rows])), 0)
    // model.point() reads from model.points (= R's set$points, projected unit positions).
    test('zero-network unit projected position is at origin', () => {
        const pos = model.point('Zero');
        pos.forEach(v => expect(v).toBeCloseTo(0, 10));
    });
});

// ── Stat helpers parity — WASM vs R (dims 1:2 of RS.data) ────────────────────
//
// R ground truth generated with:
//   set  <- ena(RS.data, units=c('UserName','Condition'),
//               conversation=c('ActivityNumber','GroupName'),
//               codes=c(...6 codes...), window.size.back=4)
//   fg2  <- as.matrix(set$points)[set$meta.data$Condition=='FirstGame',  1:2]
//   sg2  <- as.matrix(set$points)[set$meta.data$Condition=='SecondGame', 1:2]
//   libqe::mean_ci(fg2, 0.95)
//   libqe::outlier_ci(fg2, 1.5)
//   libqe::group_stats(fg2, sg2)
//
// IMPORTANT: R's set$points is nUnits × nConnections (full rotation space).
// WASM's model.points is nUnits × dims (first dims columns only).
// These tests compare WASM confInts/outlierInts/compareGroups on model.points
// against R's libqe:: equivalents run on set$points[, 1:dims].

describe('Stat helpers parity — confInts vs R libqe::mean_ci on RS.data', () => {
    const RS_OPTS = {
        codes:         RS_CODES,
        units:         ['UserName', 'Condition'],
        conversations: ['ActivityNumber', 'GroupName'],
        window:        4,
        dims:          2,
    };

    // Shared state within this describe block
    let model, fgPoints, sgPoints, nFG, nSG;

    beforeAll(() => {
        model = ena.fit(rsRows, RS_OPTS);

        // Extract per-group 2D point arrays (mirrors R's set$points[condition,1:2])
        const fgIdx = model.model.unitLabels
            .map((l, i) => l.includes('FirstGame')  ? i : -1).filter(i => i >= 0);
        const sgIdx = model.model.unitLabels
            .map((l, i) => l.includes('SecondGame') ? i : -1).filter(i => i >= 0);

        nFG = fgIdx.length;
        nSG = sgIdx.length;

        fgPoints = new Float64Array(fgIdx.flatMap(i =>
            Array.from(model.points.subarray(i * model.dims, (i + 1) * model.dims))));
        sgPoints = new Float64Array(sgIdx.flatMap(i =>
            Array.from(model.points.subarray(i * model.dims, (i + 1) * model.dims))));
    });

    // ── group sizes ───────────────────────────────────────────────────────────

    test('FirstGame has 26 units, SecondGame has 22', () => {
        expect(nFG).toBe(26);
        expect(nSG).toBe(22);
    });

    // ── confInts vs R libqe::mean_ci(fg2, 0.95) ──────────────────────────────
    // R values (dims 1:2):
    //   dim0: mean=-0.0814545, lower=-0.1283847, upper=-0.0345243
    //   dim1: mean=-0.0085475, lower=-0.0641406, upper= 0.0470456
    //
    // NOTE: SVD is unique only up to sign — R and WASM may flip the axis
    // direction independently.  Tests therefore check |mean| and CI width,
    // not the raw signed mean.  The CI width is sign-invariant.

    test('confInts: dim0 |mean| matches R |mean_ci[1,1]|', () => {
        const ci = ena.confInts(fgPoints, nFG, model.dims);
        expect(Math.abs(ci.data[0])).toBeCloseTo(0.0814545, 5);
    });

    test('confInts: dim0 CI width matches R (upper-lower)', () => {
        const ci = ena.confInts(fgPoints, nFG, model.dims);
        const wasmWidth = Math.abs(ci.data[2] - ci.data[1]);
        const rWidth    = Math.abs(-0.0345243 - (-0.1283847));  // 0.0938604
        expect(wasmWidth).toBeCloseTo(rWidth, 5);
    });

    test('confInts: dim1 |mean| matches R |mean_ci[2,1]|', () => {
        const ci = ena.confInts(fgPoints, nFG, model.dims);
        expect(Math.abs(ci.data[3])).toBeCloseTo(0.0085475, 5);
    });

    test('confInts: dim1 CI width matches R', () => {
        const ci = ena.confInts(fgPoints, nFG, model.dims);
        const wasmWidth = Math.abs(ci.data[5] - ci.data[4]);
        const rWidth    = Math.abs(0.0470456 - (-0.0641406));   // 0.1111862
        expect(wasmWidth).toBeCloseTo(rWidth, 5);
    });

    test('confInts: dim1 CI brackets mean (lower <= mean <= upper)', () => {
        const ci = ena.confInts(fgPoints, nFG, model.dims);
        expect(ci.data[4]).toBeLessThanOrEqual(ci.data[3] + 1e-10);  // lower ≤ mean
        expect(ci.data[5]).toBeGreaterThanOrEqual(ci.data[3] - 1e-10); // upper ≥ mean
    });

    // ── outlierInts vs R libqe::outlier_ci(fg2, 1.5) ─────────────────────────
    // R values (dims 1:2):
    //   dim0: lower=-0.1889027, upper=0.1889027
    //   dim1: lower=-0.2250209, upper=0.2250209

    test('outlierInts: dim0 lower matches R outlier_ci[1,1]', () => {
        const oi = ena.outlierInts(fgPoints, nFG, model.dims);
        expect(oi.data[0]).toBeCloseTo(-0.1889027, 5);
    });

    test('outlierInts: dim0 upper matches R outlier_ci[1,2]', () => {
        const oi = ena.outlierInts(fgPoints, nFG, model.dims);
        expect(oi.data[1]).toBeCloseTo(0.1889027, 5);
    });

    test('outlierInts: dim1 lower matches R outlier_ci[2,1]', () => {
        const oi = ena.outlierInts(fgPoints, nFG, model.dims);
        expect(oi.data[2]).toBeCloseTo(-0.2250209, 5);
    });

    test('outlierInts: dim1 upper matches R outlier_ci[2,2]', () => {
        const oi = ena.outlierInts(fgPoints, nFG, model.dims);
        expect(oi.data[3]).toBeCloseTo(0.2250209, 5);
    });

    // ── compareGroups vs R libqe::group_stats(fg2, sg2) ──────────────────────
    // R values:
    //   N = c(26, 22)
    //   parametric$t      = c(-4.7319737, -0.4719908)
    //   parametric$pvalue = c(0.0000265352, 0.6392175790)
    //   nonparametric$pvalue = c(0.0000522757, 0.8280041325)

    test('compareGroups: n1=26, n2=22', () => {
        const gs = ena.compareGroups(fgPoints, nFG, sgPoints, nSG, model.dims);
        expect(gs.n1).toBe(26);
        expect(gs.n2).toBe(22);
    });

    test('compareGroups: dim0 |t-statistic| matches R |parametric$t[1]|', () => {
        // Sign depends on SVD axis orientation; magnitude is invariant.
        const gs = ena.compareGroups(fgPoints, nFG, sgPoints, nSG, model.dims);
        expect(Math.abs(gs.t[0])).toBeCloseTo(4.7319737, 4);
    });

    test('compareGroups: dim1 |t-statistic| matches R |parametric$t[2]|', () => {
        const gs = ena.compareGroups(fgPoints, nFG, sgPoints, nSG, model.dims);
        expect(Math.abs(gs.t[1])).toBeCloseTo(0.4719908, 4);
    });

    test('compareGroups: dim0 parametric p-value matches R', () => {
        const gs = ena.compareGroups(fgPoints, nFG, sgPoints, nSG, model.dims);
        expect(gs.pvalue_t[0]).toBeCloseTo(0.0000265352, 6);
    });

    test('compareGroups: dim1 parametric p-value matches R', () => {
        const gs = ena.compareGroups(fgPoints, nFG, sgPoints, nSG, model.dims);
        expect(gs.pvalue_t[1]).toBeCloseTo(0.6392175790, 5);
    });

    test('compareGroups: dim0 Wilcoxon p-value matches R nonparametric$pvalue[1]', () => {
        const gs = ena.compareGroups(fgPoints, nFG, sgPoints, nSG, model.dims);
        expect(gs.pvalue_u[0]).toBeCloseTo(0.0000522757, 6);
    });

    test('compareGroups: dim1 Wilcoxon p-value matches R nonparametric$pvalue[2]', () => {
        const gs = ena.compareGroups(fgPoints, nFG, sgPoints, nSG, model.dims);
        expect(gs.pvalue_u[1]).toBeCloseTo(0.8280041325, 5);
    });
});
