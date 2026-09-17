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
 *     timesCol: 'timestamp',
 *   }
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
            const col = factors[f];
            contextLookup[i * nFactor + f] = factorLevels[col][row[col]] ?? 0;
        }
    }

    return { contextLookup, clRows: nRows, clCols: nFactor, times };
}

/**
 * Build the context_lookup with explicit timestamp column.
 */
export function buildContextLookupWithTimes(rows, rowIndices, factors, factorLevels, timesCol) {
    const nRows   = rowIndices.length;
    const nFactor = factors.length;

    const contextLookup = new Int32Array(nRows * nFactor);
    const times         = new Float64Array(nRows);

    for (let i = 0; i < nRows; i++) {
        const row = rows[rowIndices[i]];
        times[i] = Number(row[timesCol]) || i;
        for (let f = 0; f < nFactor; f++) {
            const col = factors[f];
            contextLookup[i * nFactor + f] = factorLevels[col][row[col]] ?? 0;
        }
    }

    return { contextLookup, clRows: nRows, clCols: nFactor, times };
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
        levels[col] = {};
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
 * Accumulate tensor networks for all units across all conversations.
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
 *
 * @returns {Float64Array}  nUnits × nConnections, row-major
 */
/**
 * Weighted aggregation of a unit's per-response-row directed connection counts.
 *
 * Mirrors the kernel's aggregate_row_connections but applies a weight-model
 * transform (R's weight.by) per LINE before the per-unit sum, so weight models
 * behave identically on the tensor path and the windowed path. Non-binary by
 * construction (the weight replaces the binarize step).
 *
 *   unordered: fold each directed row (m + mᵀ, upper triangle, column-major —
 *              the same order as choose_two/connection_names), weight each
 *              folded cell, then sum across rows.
 *   ordered:   weight each directed cell, then sum across rows.
 *
 * @param {Float64Array|number[]} data  Row-major (nRccRows × nCodes²) counts.
 * @param {number}   nRccRows           Number of response rows for this unit.
 * @param {number}   nCodes
 * @param {boolean}  ordered
 * @param {(x:number)=>number} weightFn
 * @returns {Float64Array}  length nCodes² (ordered) or choose_two(nCodes).
 */
function aggregateRowConnectionsWeighted(data, nRccRows, nCodes, ordered, weightFn) {
    const nSq = nCodes * nCodes;
    if (ordered) {
        const out = new Float64Array(nSq);
        for (let r = 0; r < nRccRows; r++) {
            const base = r * nSq;
            for (let c = 0; c < nSq; c++) out[c] += weightFn(data[base + c]);
        }
        return out;
    }
    const nTri = (nCodes * (nCodes - 1)) / 2;
    const out = new Float64Array(nTri);
    for (let r = 0; r < nRccRows; r++) {
        const base = r * nSq;
        let k = 0;
        for (let col = 1; col < nCodes; col++) {
            for (let row = 0; row < col; row++) {
                // fold: m(row,col) + m(col,row), column-major reshape of the row
                const folded = data[base + col * nCodes + row] +
                               data[base + row * nCodes + col];
                out[k] += weightFn(folded);
                k++;
            }
        }
    }
    return out;
}

export function accumulateTensor(qe, rows, codeMatrix, nRows, nCodes, nUnits,
                                  unitOf, convoGroups, tensorDef, ordered = false,
                                  binary = true, weightFn = null) {
    const {
        dims,
        dimsSender   = [],
        dimsReceiver = [],
        dimsMode     = [],
        factors      = [],
        data:   tensorData,
        timesCol,
    } = tensorDef;

    // Resolve factor levels (infer if not provided)
    const factorLevels = tensorDef.factorLevels ?? inferFactorLevels(rows, factors);

    const nConnections = ordered
        ? nCodes * nCodes
        : qe.choose_two(nCodes);

    const networks = new Float64Array(nUnits * nConnections);

    const dimsArr    = new Int32Array(dims);
    const senderArr  = new Int32Array(dimsSender);
    const receiverArr = new Int32Array(dimsReceiver);
    const modeArr    = new Int32Array(dimsMode);

    for (const [, rowIndices] of convoGroups) {
        const nConvo = rowIndices.length;

        // Extract code rows for this conversation
        const convoCodes = new Float64Array(nConvo * nCodes);
        for (let r = 0; r < nConvo; r++) {
            const src = rowIndices[r];
            convoCodes.set(
                codeMatrix.subarray(src * nCodes, src * nCodes + nCodes),
                r * nCodes
            );
        }

        // Build context_lookup and times for this conversation
        const { contextLookup, clRows, clCols, times } = timesCol
            ? buildContextLookupWithTimes(rows, rowIndices, factors, factorLevels, timesCol)
            : buildContextLookup(rows, rowIndices, factors, factorLevels);

        // Group response rows by unit (within this conversation)
        const unitConvoRows = new Map();
        for (let r = 0; r < nConvo; r++) {
            const unit = unitOf[rowIndices[r]];
            if (!unitConvoRows.has(unit)) unitConvoRows.set(unit, []);
            unitConvoRows.get(unit).push(r);  // local (conversation-relative) index
        }

        // Accumulate per unit
        for (const [unit, localRows] of unitConvoRows) {
            const unitRowsArr = new Int32Array(localRows);

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
                unitRowsArr,
                convoCodes, nConvo, nCodes,
                times,
                true
            );

            // Aggregate the raw per-response-row connections into this unit's
            // network exactly as tma does in R: fold each row to the upper
            // triangle and binarize per row (unordered), or plain-sum the
            // directed rows (ordered).  This lives in the libqe kernel so the
            // fold/binarize/sum semantics are shared across every binding.
            const rcc = result.row_connection_counts;
            // A weight model (R's weight.by) applies its transform per line to
            // the folded connection counts before summing — identical stage to
            // the windowed path — so weight models behave the same on both
            // paths. Otherwise defer the fold/binarize/sum to the shared kernel.
            const unitVec = weightFn
                ? aggregateRowConnectionsWeighted(rcc.data, rcc.rows, nCodes, ordered, weightFn)
                : qe.aggregate_row_connections(
                    rcc.data, rcc.rows, rcc.cols, nCodes, ordered, binary
                );
            for (let c = 0; c < nConnections; c++) {
                networks[unit * nConnections + c] += unitVec[c];
            }
        }
    }

    return networks;
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
