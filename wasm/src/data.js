/**
 * data.js — Data parsing and unit/conversation grouping for ENA.
 *
 * Converts an array of row objects (e.g. parsed CSV rows) into the flat
 * Float64Array code matrix and unit/conversation index structures that the
 * pipeline needs.  Also extracts per-unit metadata (non-code, non-unit,
 * non-conversation columns), mirroring R's enadata$metadata / set$meta.data.
 */

/**
 * Build a composite key from multiple column values.
 * @param {Object} row
 * @param {string[]} cols
 * @returns {string}
 */
export function rowKey(row, cols) {
    return cols.map(c => row[c]).join('__');
}

// rowKey() is the label callers see (and pass back as unitsUsed), but joining
// with '__' is ambiguous: {a: 'x__y', b: 'z'} and {a: 'x', b: 'y__z'} both give
// 'x__y__z'. Track the exact values behind each label and refuse to merge
// different ones under the same label.
function checkedKey(seen, row, cols, what) {
    const key   = rowKey(row, cols);
    const exact = JSON.stringify(cols.map(c => row[c] ?? null));
    const prev  = seen.get(key);
    if (prev === undefined) seen.set(key, exact);
    else if (prev !== exact) {
        throw new Error(`Different ${what} values both map to "${key}" because a value ` +
                        `contains "__"; rename the values or use different ${what} columns.`);
    }
    return key;
}

function requireColumns(kind, cols, available) {
    if (!Array.isArray(cols) || cols.length === 0 || !cols.every(c => typeof c === 'string')) {
        throw new Error(`${kind} must be a non-empty array of column names`);
    }
    const missing = cols.filter(c => !available.has(c));
    if (missing.length) {
        throw new Error(`${kind}: column(s) not found in the data: ${missing.join(', ')}`);
    }
}

/**
 * Parse tabular data into ENA-ready structures.
 *
 * @param {Object[]} rows       - Array of row objects (one per utterance/event)
 * @param {string[]} codes      - Code column names
 * @param {string[]} unitCols   - Column(s) that identify a unit (e.g. ['UserName', 'Condition'])
 * @param {string[]} convoCols  - Column(s) that identify a conversation (e.g. ['Condition', 'GroupName'])
 * @param {string[]|null} [unitsUsed=null] - Unit keys (rowKey format) to model
 *   (= R's `units.used`). Rows of other units stay in their conversations, so
 *   they still count as context in the included units' windows, but they get
 *   no unit (unitOf = -1) and so produce no network. null = every unit.
 *
 * @returns {{
 *   codeMatrix:  Float64Array,            // n_rows × n_codes, row-major
 *   nRows:       number,
 *   nCodes:      number,
 *   nUnits:      number,
 *   unitLabels:  string[],                // unit key for each unit index
 *   unitOf:      Int32Array,              // unit index for each row (-1 = not a modeled unit)
 *   convoOf:     Int32Array,              // conversation index for each row
 *   convoGroups: Map<number, number[]>,   // convoIdx → [rowIdx, ...]
 *   metaData:    Object[],               // one metadata object per unit (first-row representative)
 *   metaCols:    string[],               // names of metadata columns
 * }}
 */
export function parseData(rows, codes, unitCols, convoCols, unitsUsed = null) {
    const nRows  = rows.length;
    const nCodes = codes.length;

    const codeMatrix  = new Float64Array(nRows * nCodes);
    const unitOf      = new Int32Array(nRows);
    const convoOf     = new Int32Array(nRows);

    const unitIndex   = new Map();   // key → index
    const convoIndex  = new Map();   // key → index
    const convoGroups = new Map();   // convoIdx → [rowIdx, ...]

    // Metadata columns: every column that is NOT a code, unit, or convo column.
    const allCols      = nRows > 0 ? Object.keys(rows[0]) : [];
    // A misspelled column used to read as undefined everywhere: all-zero codes,
    // or every row in one unit called "undefined".
    if (nRows > 0) {
        const available = new Set(allCols);
        requireColumns('codes', codes, available);
        requireColumns('units', unitCols, available);
        requireColumns('conversations', convoCols, available);
    }
    const excludedCols = new Set([...codes, ...unitCols, ...convoCols]);
    const metaCols     = allCols.filter(c => !excludedCols.has(c));
    const unitSeen     = new Map();   // label → exact values (see checkedKey)
    const convoSeen    = new Map();

    // Per-unit metadata rows — populated on first occurrence of each unit.
    const metaData = [];

    const used = unitsUsed ? new Set(unitsUsed.map(String)) : null;

    for (let i = 0; i < nRows; i++) {
        const row = rows[i];

        // Code values: numbers, numeric strings or booleans. A missing or
        // non-numeric value is an error rather than a silent 0.
        for (let c = 0; c < nCodes; c++) {
            const raw = row[codes[c]];
            const v   = typeof raw === 'string' && raw.trim() === '' ? NaN : Number(raw);
            if (!Number.isFinite(v)) {
                throw new Error(`Code "${codes[c]}" has a missing or non-numeric value ` +
                                `(${JSON.stringify(raw ?? null)}) in row ${i + 1}`);
            }
            codeMatrix[i * nCodes + c] = v;
        }

        // Unit index
        const uKey = checkedKey(unitSeen, row, unitCols, 'unit');
        if (used && !used.has(uKey)) {
            unitOf[i] = -1;
        } else if (!unitIndex.has(uKey)) {
            const uIdx = unitIndex.size;
            unitIndex.set(uKey, uIdx);
            // First row for this unit → representative metadata
            const meta = {};
            for (const col of metaCols) meta[col] = row[col];
            metaData[uIdx] = meta;
        }
        if (unitOf[i] !== -1) unitOf[i] = unitIndex.get(uKey);

        // Conversation index
        const cKey = checkedKey(convoSeen, row, convoCols, 'conversation');
        if (!convoIndex.has(cKey)) convoIndex.set(cKey, convoIndex.size);
        const cIdx = convoIndex.get(cKey);
        convoOf[i] = cIdx;

        if (!convoGroups.has(cIdx)) convoGroups.set(cIdx, []);
        convoGroups.get(cIdx).push(i);
    }

    const unitLabels = Array.from(unitIndex.keys());
    const nUnits     = unitLabels.length;
    if (used && nUnits === 0) {
        throw new Error('opts.unitsUsed matched no units in the data');
    }

    return { codeMatrix, nRows, nCodes, nUnits, unitLabels, unitOf, convoOf, convoGroups,
             metaData, metaCols };
}
