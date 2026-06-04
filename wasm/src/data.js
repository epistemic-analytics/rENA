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

/**
 * Parse tabular data into ENA-ready structures.
 *
 * @param {Object[]} rows       - Array of row objects (one per utterance/event)
 * @param {string[]} codes      - Code column names
 * @param {string[]} unitCols   - Column(s) that identify a unit (e.g. ['UserName', 'Condition'])
 * @param {string[]} convoCols  - Column(s) that identify a conversation (e.g. ['Condition', 'GroupName'])
 *
 * @returns {{
 *   codeMatrix:  Float64Array,            // n_rows × n_codes, row-major
 *   nRows:       number,
 *   nCodes:      number,
 *   nUnits:      number,
 *   unitLabels:  string[],                // unit key for each unit index
 *   unitOf:      Int32Array,              // unit index for each row
 *   convoOf:     Int32Array,              // conversation index for each row
 *   convoGroups: Map<number, number[]>,   // convoIdx → [rowIdx, ...]
 *   metaData:    Object[],               // one metadata object per unit (first-row representative)
 *   metaCols:    string[],               // names of metadata columns
 * }}
 */
export function parseData(rows, codes, unitCols, convoCols) {
    const nRows  = rows.length;
    const nCodes = codes.length;

    const codeMatrix  = new Float64Array(nRows * nCodes);
    const unitOf      = new Int32Array(nRows);
    const convoOf     = new Int32Array(nRows);

    const unitIndex   = new Map();   // key → index
    const convoIndex  = new Map();   // key → index
    const convoGroups = new Map();   // convoIdx → [rowIdx, ...]

    // Metadata columns: every column that is NOT a code, unit, or convo column.
    const excludedCols = new Set([...codes, ...unitCols, ...convoCols]);
    const allCols      = nRows > 0 ? Object.keys(rows[0]) : [];
    const metaCols     = allCols.filter(c => !excludedCols.has(c));

    // Per-unit metadata rows — populated on first occurrence of each unit.
    const metaData = [];

    for (let i = 0; i < nRows; i++) {
        const row = rows[i];

        // Code values
        for (let c = 0; c < nCodes; c++) {
            codeMatrix[i * nCodes + c] = Number(row[codes[c]]) || 0;
        }

        // Unit index
        const uKey = rowKey(row, unitCols);
        if (!unitIndex.has(uKey)) {
            const uIdx = unitIndex.size;
            unitIndex.set(uKey, uIdx);
            // First row for this unit → representative metadata
            const meta = {};
            for (const col of metaCols) meta[col] = row[col];
            metaData[uIdx] = meta;
        }
        unitOf[i] = unitIndex.get(uKey);

        // Conversation index
        const cKey = rowKey(row, convoCols);
        if (!convoIndex.has(cKey)) convoIndex.set(cKey, convoIndex.size);
        const cIdx = convoIndex.get(cKey);
        convoOf[i] = cIdx;

        if (!convoGroups.has(cIdx)) convoGroups.set(cIdx, []);
        convoGroups.get(cIdx).push(i);
    }

    const unitLabels = Array.from(unitIndex.keys());
    const nUnits     = unitLabels.length;

    return { codeMatrix, nRows, nCodes, nUnits, unitLabels, unitOf, convoOf, convoGroups,
             metaData, metaCols };
}
