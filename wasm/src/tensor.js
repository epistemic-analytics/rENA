/**
 * tensor.js — Context-tensor accumulation for rENA WASM.
 *
 * Maps tma's apply_tensor() semantics to the JS/WASM layer.  Each unit's
 * network is accumulated by calling qe.accumulate_tensor_unit() with a
 * multi-dimensional tensor that encodes per-factor-combination window sizes
 * and weights.
 *
 * Tensor definition (passed as `opts.tensor` to fit/accumulate):
 *
 *   {
 *     // Tensor shape.  Last entry is always 2 (index 0 = weight, index 1 = window).
 *     // Earlier entries correspond to the factor columns in order.
 *     dims: [nValsFactor0, nValsFactor1, ..., 2],
 *
 *     // Which factor axes (0-based, NOT including the last weight/window axis)
 *     // act as sender / receiver / mode dimensions.
 *     dimsSender:   [0],      // e.g. axis 0 is a sender factor
 *     dimsReceiver: [1],      // e.g. axis 1 is a receiver factor
 *     dimsMode:     [],
 *
 *     // Column names in the data — one per factor axis, matching dims[0..n-2].
 *     factors: ['SenderType', 'ReceiverType'],
 *
 *     // Maps each factor column's string values to 0-based integer indices.
 *     // If omitted, values are encoded in order of first appearance.
 *     factorLevels: {
 *       SenderType:   { 'A': 0, 'B': 1, 'C': 2 },
 *       ReceiverType: { 'X': 0, 'Y': 1, 'Z': 2 },
 *     },
 *
 *     // Flat column-major tensor data: weight and window for every factor
 *     // combination.  Length must equal product(dims).
 *     // Index 0 along last axis = weight; index 1 along last axis = window.
 *     data: new Float64Array([...]),
 *
 *     // Optional column name for per-row timestamps.
 *     // Defaults to row index (0, 1, 2, ...) — equivalent to unit-step time.
 *     // Numeric columns are used as-is; otherwise every value is parsed as
 *     // elapsed time (MM:SS, HH:MM:SS) or a date-time, in seconds (parseTimes).
 *     timesCol: 'timestamp',
 *
 *     // Optional unit the windows in `data` are expressed in when timesCol is
 *     // set: 'secs' (default) | 'mins' | 'hours' | 'days' | 'weeks'. Windows
 *     // are converted to seconds before accumulation, as rENA.api does with
 *     // mins_to_seconds() etc.
 *     timeUnit: 'mins',
 *
 *     // Optional end-time column (rENA.api's timeend_column). A numeric column
 *     // is a duration added to the start time; anything else is parsed as the
 *     // row's end timestamp. Either way the row's time becomes its end time.
 *     timesEndCol: 'duration',
 *   }
 *
 * A window of Infinity (e.g. defaultTensor(Infinity), = rENA's
 * window.size.back = Inf) includes every earlier line of the conversation.
 *
 * Simple windowed accumulation (IS_DEFAULT path):
 *   Pass `{ dims: [2], dimsSender: [], dimsReceiver: [], dimsMode: [],
 *            factors: [], data: Float64Array.of(weight, window) }`
 *   or just use the `window` shorthand on the outer opts instead.
 */

/**
 * Build the context_lookup matrix and times vector from row data.
 *
 * @param {Object[]}        rows          All data rows (full dataset)
 * @param {number[]}        rowIndices    Indices into rows for this conversation
 * @param {string[]}        factors       Factor column names
 * @param {Object}          factorLevels  { colName: { value: index } }
 * @returns {{ contextLookup: Int32Array, clRows: number, clCols: number,
 *             times: Float64Array }}
 */
export function buildContextLookup(rows, rowIndices, factors, factorLevels) {
    const nRows   = rowIndices.length;
    const nFactor = factors.length;

    const contextLookup = new Int32Array(nRows * nFactor);
    const times         = new Float64Array(nRows);

    for (let i = 0; i < nRows; i++) {
        const row = rows[rowIndices[i]];
        times[i] = i;  // default: row index as time
        for (let f = 0; f < nFactor; f++) {
            const col    = factors[f];
            const levels = factorLevels[col];
            // Own properties only: a value like "constructor" must not resolve
            // to an inherited Object.prototype member. A value with no level
            // used to fall back to level 0 silently.
            if (!levels || !Object.prototype.hasOwnProperty.call(levels, row[col])) {
                throw new Error(`tensor factor "${col}" has no level for value ` +
                                `${JSON.stringify(row[col] ?? null)}`);
            }
            contextLookup[i * nFactor + f] = levels[row[col]];
        }
    }

    return { contextLookup, clRows: nRows, clCols: nFactor, times };
}

/**
 * Build the context_lookup with explicit per-row times.
 *
 * @param {Float64Array} allTimes  time of every row in `rows` (see parseTimes)
 */
export function buildContextLookupWithTimes(rows, rowIndices, factors, factorLevels, allTimes) {
    const ctx = buildContextLookup(rows, rowIndices, factors, factorLevels);
    for (let i = 0; i < rowIndices.length; i++) ctx.times[i] = allTimes[rowIndices[i]];
    return ctx;
}

// Seconds per window unit (= rENA.api's mins_to_seconds, hours_to_seconds, ...).
const SECONDS_PER = { secs: 1, mins: 60, hours: 3600, days: 86400, weeks: 604800 };

/**
 * Seconds per unit of a time-window unit name ('secs', 'mins', 'hours',
 * 'days', 'weeks'; quotes and a trailing 's' are optional). 'lines' and empty
 * values return null (no time scaling).
 */
export function secondsPerTimeUnit(unit) {
    if (unit == null) return null;
    let u = String(unit).replace(/['"]/g, '').trim().toLowerCase();
    if (u === '' || u === 'lines' || u === 'auto') return null;
    if (u === 'minutes' || u === 'min') u = 'mins';
    if (u === 'seconds' || u === 'sec') u = 'secs';
    if (!u.endsWith('s')) u += 's';
    if (!(u in SECONDS_PER)) throw new Error(`Unknown time unit '${unit}'`);
    return SECONDS_PER[u];
}

const pad2 = (s) => (s.length === 1 ? '0' + s : s);

// Date-time formats rENA.api's parse_date tries, in the same order. Each
// pattern captures the fields named in `order`; a match is accepted only when
// the fields form a real date (so 9/17/2013 is rejected as d/m/Y and falls
// through to m/d/Y, exactly as as.POSIXct returns NA for it in R).
const DATE_FORMATS = [
    { re: /^(\d{4})-(\d{2})-(\d{2})$/,                                  order: 'Ymd' },
    { re: /^(\d{2})\/(\d{2})\/(\d{4})$/,                                order: 'dmY' },
    { re: /^(\d{2})\/(\d{2})\/(\d{4})$/,                                order: 'mdY' },
    { re: /^(\d{4})\/(\d{2})\/(\d{2})$/,                                order: 'Ymd' },
    { re: /^(\d{2})-(\d{2})-(\d{4})$/,                                  order: 'mdY' },
    { re: /^(\d{2})-(\d{2})-(\d{4})$/,                                  order: 'dmY' },
    { re: /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/,           order: 'YmdHMS' },
    { re: /^(\d{2})\/(\d{2})\/(\d{4}) (\d{2}):(\d{2}):(\d{2})$/,         order: 'dmYHMS' },
    { re: /^(\d{2})\/(\d{2})\/(\d{4}) (\d{2}):(\d{2}):(\d{2})$/,         order: 'mdYHMS' },
    { re: /^(\d{2})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2})$/,                 order: 'mdyHM' },
    { re: /^(\d{2})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2})$/,                 order: 'dmyHM' },
    { re: /^(\d{1,2})\/(\d{1,2})\/(\d{4}) (\d{2}):(\d{2})$/,             order: 'mdYHM' },
    { re: /^(\d{1,2})\/(\d{1,2})\/(\d{2}) (\d{2}):(\d{2})$/,             order: 'mdyHM' },
];

/**
 * Parse one time value to seconds (= rENA.api's parse_date): elapsed
 * "MM:SS" / "HH:MM:SS" → total seconds; a date-time → seconds since the
 * epoch (UTC). Returns NaN when the value matches no supported format.
 */
export function parseTimeValue(value) {
    let s = String(value).trim();
    s = s.replace(/ (\d):/g, ' 0$1:')
         .replace(/^(\d)(\/|-)/, '0$1$2')
         .replace(/(\/|-)(\d)(\/|-)/g, (_, a, d, b) => a + '0' + d + b);

    let m;
    if ((m = /^(\d{1,2}):(\d{2})$/.exec(s)))        return (+m[1]) * 60 + (+m[2]);
    if ((m = /^(\d{1,3}):(\d{2}):(\d{2})$/.exec(s))) return (+m[1]) * 3600 + (+m[2]) * 60 + (+m[3]);

    for (const { re, order } of DATE_FORMATS) {
        if (!(m = re.exec(s))) continue;
        const f = { Y: null, m: 1, d: 1, H: 0, M: 0, S: 0 };
        for (let i = 0; i < order.length; i++) {
            const v = +m[i + 1];
            if (order[i] === 'y') f.Y = v <= 68 ? 2000 + v : 1900 + v;  // R's %y pivot
            else f[order[i]] = v;
        }
        if (f.m < 1 || f.m > 12 || f.d < 1 || f.H > 23 || f.M > 59 || f.S > 61) continue;
        const ms = Date.UTC(f.Y, f.m - 1, f.d, f.H, f.M, f.S);
        if (new Date(ms).getUTCDate() !== f.d) continue;             // e.g. 31/02
        return ms / 1000;
    }
    return NaN;
}

/**
 * Per-row times, in seconds, for a time column (= rENA.api's handling of
 * time_column / timeend_column before tma::accumulate). A column whose values
 * are all numeric is used as-is; otherwise every value is parsed with
 * parseTimeValue(). With `endCol`, a numeric end column is a duration added
 * to the start, and any other end column is parsed as the end timestamp.
 *
 * @param {Object[]}    rows
 * @param {string}      col
 * @param {string|null} [endCol=null]
 * @returns {Float64Array}
 * @throws when a value cannot be parsed as a time
 */
export function parseTimes(rows, col, endCol = null) {
    const column = (name) => {
        const vals = rows.map(r => r[name]);
        const blank = (v) => v === undefined || v === null || String(v).trim() === '';
        const nums = vals.map(v => (blank(v) ? NaN : Number(v)));
        const numeric = nums.every((n, i) => !Number.isNaN(n) || blank(vals[i]));
        const out = new Float64Array(rows.length);
        for (let i = 0; i < rows.length; i++) {
            const t = numeric ? nums[i] : parseTimeValue(vals[i]);
            if (Number.isNaN(t)) {
                throw new Error(`Unable to read '${vals[i]}' (row ${i + 1}) in time column '${name}' as a time`);
            }
            out[i] = t;
        }
        return { out, numeric };
    };

    const start = column(col).out;
    if (!endCol) return start;
    const end = column(endCol);
    if (end.numeric) for (let i = 0; i < start.length; i++) end.out[i] += start[i];
    return end.out;
}

/**
 * Auto-build factorLevels from data when not explicitly provided.
 * Scans all rows and assigns integer indices in order of first appearance.
 *
 * @param {Object[]} rows
 * @param {string[]} factors
 * @returns {Object}  { colName: { value: index, ... }, ... }
 */
export function inferFactorLevels(rows, factors) {
    const levels = {};
    for (const col of factors) {
        // No prototype: values such as "constructor" or "__proto__" are
        // ordinary keys here.
        levels[col] = Object.create(null);
        let idx = 0;
        for (const row of rows) {
            const v = row[col];
            if (v !== undefined && !(v in levels[col])) {
                levels[col][v] = idx++;
            }
        }
    }
    return levels;
}

/**
 * Check a tensor definition before it reaches libqe, which indexes the
 * tensor with these values (an index out of range used to read past it).
 */
export function validateTensor(dims, tensorData, factors, factorLevels) {
    if (!Array.isArray(dims) && !ArrayBuffer.isView(dims)) {
        throw new Error('tensor dims must be an array');
    }
    const d = Array.from(dims);
    if (d.length === 0 || !d.every(x => Number.isInteger(x) && x > 0)) {
        throw new Error('tensor dims must be positive integers');
    }
    const size = d.reduce((a, b) => a * b, 1);
    if (size !== tensorData.length) {
        throw new Error(`tensor data has ${tensorData.length} values but dims ` +
                        `[${d.join(', ')}] need ${size}`);
    }
    if (factors.length > 0 && d.length !== factors.length + 1) {
        throw new Error(`tensor dims need one axis per factor (${factors.length}) ` +
                        `plus the weight/window axis; got ${d.length}`);
    }
    factors.forEach((col, f) => {
        const levels = factorLevels[col];
        if (!levels) throw new Error(`no factor levels for tensor factor "${col}"`);
        for (const [value, level] of Object.entries(levels)) {
            if (!Number.isInteger(level) || level < 0 || level >= d[f]) {
                throw new Error(`level ${level} of "${col}" = ${JSON.stringify(value)} ` +
                                `is outside its axis (size ${d[f]})`);
            }
        }
    });
}

// libqe's apply_tensor_unit reads the IS_DEFAULT window as an int, so an
// infinite window (or one too large for int32) is clamped to INT32_MAX — still
// longer than any conversation, in lines or in seconds.
const MAX_WINDOW = 2147483647;

/**
 * The tensor data libqe accumulates with: windows (the second half of the
 * column-major data, index 1 along the last axis) converted from `timeUnit`
 * to seconds when a time column is in use, and infinite / oversized windows
 * clamped to MAX_WINDOW. Weights are left unchanged.
 */
export function resolveTensorData(tensorDef) {
    const data  = Float64Array.from(tensorDef.data);
    const nComb = data.length / 2;
    const scale = tensorDef.timesCol ? (secondsPerTimeUnit(tensorDef.timeUnit) ?? 1) : 1;
    for (let c = nComb; c < data.length; c++) {
        const w = data[c] * scale;
        data[c] = (Number.isNaN(w) || w > MAX_WINDOW) ? MAX_WINDOW : w;
    }
    return data;
}

/**
 * Per-unit horizon-of-observation contexts (= tma::contexts with rENA.api's
 * flexible-horizon rules). `horizons.rules` maps each value of the
 * discriminator column `horizons.by` to the columns that define that
 * horizon. A row with discriminator value x is in unit U's context when every
 * rule-x column holds a value U has on at least one of its rows
 * (`col %in% UNIT$col`); rows whose value has no rule are in no context. Each
 * unit's context is then split on the union of every rule's columns (NOT on
 * the discriminator, which only picks the rule), and the moving window runs
 * within each piece.
 *
 * @param {Object[]}   rows
 * @param {Int32Array} unitOf   unit index per row (-1 = not a modeled unit)
 * @param {number}     nUnits
 * @param {{ by: string, rules: Object<string, string[]> }} horizons
 * @returns {number[][][]}  per unit, its context pieces as ascending row indices
 */
export function buildHorizonContexts(rows, unitOf, nUnits, horizons) {
    const { by, rules } = horizons || {};
    if (!by) throw new Error('horizons.by (the discriminator column) is required');
    const ruleCols = new Map();
    for (const [value, cols] of Object.entries(rules || {})) {
        if (!Array.isArray(cols) || cols.length === 0) {
            throw new Error(`horizon '${value}' of '${by}' has no columns assigned`);
        }
        ruleCols.set(String(value), cols);
    }
    if (ruleCols.size === 0) throw new Error('horizons.rules must define at least one horizon');
    const splitCols = [...new Set([].concat(...ruleCols.values()))];

    // UNIT$col: every value each unit takes on each rule column.
    const unitVals = Array.from({ length: nUnits }, () => new Map(splitCols.map(c => [c, new Set()])));
    for (let i = 0; i < rows.length; i++) {
        const u = unitOf[i];
        if (u < 0) continue;
        for (const c of splitCols) unitVals[u].get(c).add(String(rows[i][c]));
    }

    return unitVals.map((vals) => {
        const pieces = new Map();   // split key → row indices (first-appearance order)
        for (let i = 0; i < rows.length; i++) {
            const cols = ruleCols.get(String(rows[i][by]));
            if (!cols || !cols.every(c => vals.get(c).has(String(rows[i][c])))) continue;
            const key = splitCols.map(c => String(rows[i][c])).join('\u0000');
            if (!pieces.has(key)) pieces.set(key, []);
            pieces.get(key).push(i);
        }
        return [...pieces.values()];
    });
}

/**
 * Accumulate tensor networks for all units across all conversations.
 *
 * Every accumulation — including plain windowed ENA, via defaultTensor(window)
 * — runs through here, so the per-line finalisation (fold / binarize / weight)
 * lives in exactly one place.
 *
 * @param {object}      qe             libqe WASM module
 * @param {Object[]}    rows           Full dataset
 * @param {Float64Array} codeMatrix   n_rows × n_codes, row-major
 * @param {number}      nRows
 * @param {number}      nCodes
 * @param {number}      nUnits
 * @param {Int32Array}  unitOf         unit index per row
 * @param {Map}         convoGroups    convoIdx → [rowIdx, ...]
 * @param {object}      tensorDef      Tensor definition (see module docstring)
 * @param {boolean}     ordered        true → directed (n²); false → undirected
 * @param {boolean}     [binary=true]  binarize each folded row (unordered only);
 *                                     used when no weight model is given
 * @param {string|null} [weight=null]  libqe weight model applied per line before
 *                                     the unit sum: 'binary' | 'product' |
 *                                     'sqrt' | 'log1p'
 * @param {object|null} [horizons=null] flexible horizons (see
 *                                     buildHorizonContexts); replaces
 *                                     convoGroups as the windowing contexts
 *
 * @returns {{ networks: Float64Array, rowConnectionCounts: Float64Array }}
 *   networks            nUnits × nConnections, row-major
 *   rowConnectionCounts nRows × nConnections, row-major — each row's finalised
 *                       (folded / binarized / weighted) connection vector;
 *                       rows sum by unit to `networks`
 */
export function accumulateTensor(qe, rows, codeMatrix, nRows, nCodes, nUnits,
                                  unitOf, convoGroups, tensorDef, ordered = false,
                                  binary = true, weight = null, horizons = null) {
    const {
        dims,
        dimsSender   = [],
        dimsReceiver = [],
        dimsMode     = [],
        factors      = [],
        timesCol,
        timesEndCol,
    } = tensorDef;
    const tensorData = resolveTensorData(tensorDef);

    // Resolve factor levels (infer if not provided)
    const factorLevels = tensorDef.factorLevels ?? inferFactorLevels(rows, factors);
    validateTensor(dims, tensorData, factors, factorLevels);
    const allTimes = timesCol ? parseTimes(rows, timesCol, timesEndCol || null) : null;

    const nConnections = ordered
        ? nCodes * nCodes
        : qe.choose_two(nCodes);

    const networks            = new Float64Array(nUnits * nConnections);
    const rowConnectionCounts = new Float64Array(nRows * nConnections);

    // libqe weight argument: a weight-model name, or the legacy binary flag.
    const kernelWeight = weight ?? binary;

    const dimsArr    = new Int32Array(dims);
    const senderArr  = new Int32Array(dimsSender);
    const receiverArr = new Int32Array(dimsReceiver);
    const modeArr    = new Int32Array(dimsMode);

    // Accumulate `unit`'s response rows (`localRows`, indices into
    // `rowIndices`) within one context of rows.
    const accumulateContext = (rowIndices, unit, localRows) => {
        const nCtx = rowIndices.length;

        // Extract code rows for this context
        const ctxCodes = new Float64Array(nCtx * nCodes);
        for (let r = 0; r < nCtx; r++) {
            const src = rowIndices[r];
            ctxCodes.set(
                codeMatrix.subarray(src * nCodes, src * nCodes + nCodes),
                r * nCodes
            );
        }

        // Build context_lookup and times for this context
        const { contextLookup, clRows, clCols, times } = allTimes
            ? buildContextLookupWithTimes(rows, rowIndices, factors, factorLevels, allTimes)
            : buildContextLookup(rows, rowIndices, factors, factorLevels);

        // Always accumulate the DIRECTED per-response-row counts (ordered
        // kernel), exactly as tma does — it calls apply_tensor with the
        // default ordered=TRUE and defers the ordered-vs-unordered decision
        // to aggregation.  Passing the unordered flag here would make the
        // kernel emit an already-symmetric matrix that the fold below would
        // then double-count.
        const result = qe.accumulate_tensor_unit(
            tensorData, dimsArr,
            senderArr, receiverArr, modeArr,
            contextLookup, clRows, clCols,
            new Int32Array(localRows),
            ctxCodes, nCtx, nCodes,
            times,
            true
        );

        // Finalise each raw per-response-row connection vector with libqe's
        // shared kernel, exactly as tma does in R: fold to the upper
        // triangle (unordered) or keep the directed row (ordered), then
        // apply the weight model per line (binary clamp, product, sqrt,
        // log1p) before the per-unit sum. Row i is local row localRows[i].
        const rcc = result.row_connection_counts;
        const fin = qe.finalize_row_connections(
            rcc.data, rcc.rows, rcc.cols, nCodes, ordered, kernelWeight
        );
        const unitOff = unit * nConnections;
        for (let i = 0; i < fin.rows; i++) {
            const rowOff = rowIndices[localRows[i]] * nConnections;
            const finOff = i * fin.cols;
            for (let c = 0; c < nConnections; c++) {
                const v = fin.data[finOff + c];
                rowConnectionCounts[rowOff + c] = v;
                networks[unitOff + c] += v;
            }
        }
    };

    if (horizons) {
        // Flexible horizons: every unit has its own contexts.
        const unitContexts = buildHorizonContexts(rows, unitOf, nUnits, horizons);
        unitContexts.forEach((pieces, unit) => {
            for (const rowIndices of pieces) {
                const localRows = [];
                for (let r = 0; r < rowIndices.length; r++) {
                    if (unitOf[rowIndices[r]] === unit) localRows.push(r);
                }
                if (localRows.length) accumulateContext(rowIndices, unit, localRows);
            }
        });
        return { networks, rowConnectionCounts };
    }

    for (const [, rowIndices] of convoGroups) {
        // Group response rows by unit (within this conversation). Rows with
        // no unit (unitOf = -1, excluded via unitsUsed) are never responses,
        // but stay in the context for the other units' windows.
        const unitConvoRows = new Map();
        for (let r = 0; r < rowIndices.length; r++) {
            const unit = unitOf[rowIndices[r]];
            if (unit < 0) continue;
            if (!unitConvoRows.has(unit)) unitConvoRows.set(unit, []);
            unitConvoRows.get(unit).push(r);  // local (conversation-relative) index
        }
        for (const [unit, localRows] of unitConvoRows) {
            accumulateContext(rowIndices, unit, localRows);
        }
    }

    return { networks, rowConnectionCounts };
}

/**
 * Build an IS_DEFAULT tensor definition from a simple window + weight.
 * Use this to express simple windowed accumulation through the tensor path.
 *
 * @param {number} windowSize
 * @param {number} [weight=1]
 * @returns {object} tensorDef
 */
export function defaultTensor(windowSize, weight = 1) {
    return {
        dims:         [2],
        dimsSender:   [],
        dimsReceiver: [],
        dimsMode:     [],
        factors:      [],
        factorLevels: {},
        data:         Float64Array.of(weight, windowSize),
    };
}
